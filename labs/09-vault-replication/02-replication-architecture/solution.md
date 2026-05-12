---
title: Đáp án mẫu — Phân tích kiến trúc Vault Replication đa vùng
---

# Đáp án mẫu

> Đây là lời giải chuẩn cho bài thực hành. Các bước phân tích kiến trúc (Bước 1-3) là bài tập tư duy — câu trả lời có thể diễn đạt khác nhau, miễn là đúng về mặt kỹ thuật. Bước 4 có thể chạy lệnh và kiểm tra bằng `sh verify.sh`.

## Bước 1: Thiết kế topology

### (a) Topology đầy đủ

```
Primary US ──[DR Replication]──> DR-US
     │
     ├──[Performance Replication]──> EU Performance
     │                                      │
     │                              [DR Replication]
     │                                      │
     │                                   DR-EU
     │
     └──[Performance Replication]──> APAC Performance
                                            │
                                    [DR Replication]
                                            │
                                         DR-APAC
```

Chiều replication:
- Primary US gửi dữ liệu sang DR-US (DR Replication).
- Primary US gửi dữ liệu sang EU Performance và APAC Performance (Performance Replication).
- EU Performance cluster gửi dữ liệu sang DR-EU (DR Replication).
- APAC Performance cluster gửi dữ liệu sang DR-APAC (DR Replication).

Đây là mẫu **region-protected**: mỗi vùng có cluster phục vụ cục bộ và cluster dự phòng riêng của nó.

### (b) Client EU nên authenticate với EU Performance cluster

Client EU nên authenticate trực tiếp với EU Performance cluster (không phải Primary US) vì:

1. **Latency**: EU cluster gần client EU hơn về địa lý, giảm thời gian authenticate.
2. **Token locality**: token tạo trên EU cluster là token cục bộ của EU cluster. Token đó được DR-EU replicate — nếu EU cluster sập và DR-EU được promote, token vẫn hợp lệ trên DR-EU.
3. **Token tạo trên Primary US KHÔNG được replicate sang EU cluster** (Performance Replication không replicate token). Nếu client EU lấy token từ Primary US và EU cluster sập, client phải re-authenticate vì DR-EU không có token từ Primary US.

### (c) Token EU được replicate đến đâu

Token tạo trên EU Performance cluster:
- **Được replicate đến**: DR-EU (vì DR Replication replicate toàn bộ state kể cả token/lease).
- **Không được replicate đến**: Primary US, APAC Performance cluster, DR-US, DR-APAC.

Lý do: Performance Replication (EU -> Primary US hoặc EU -> APAC) không replicate token. Chỉ DR Replication (EU -> DR-EU) mới replicate token.

---

## Bước 2: Phân tích tình huống failover EU cluster

### (a) Các bước xử lý khi EU Performance cluster sập

1. **Xác nhận DR-EU đang chạy bình thường** và có bản sao đủ mới của EU cluster.
2. **Chuẩn bị DR Operation Token** (nếu chưa có sẵn — lý tưởng là đã tạo sẵn trước sự cố từ EU cluster).
3. **Promote DR-EU lên** bằng lệnh promote với DR Operation Token:
   ```bash
   vault write sys/replication/dr/secondary/promote \
     dr_operation_token=<EU_DR_OPERATION_TOKEN>
   ```
4. **Redirect client EU traffic sang DR-EU**: cập nhật DNS record hoặc load balancer để trỏ về DR-EU.
5. **Theo dõi trạng thái**: DR-EU tự động tham gia lại performance replication set với Primary US.

### (b) Trạng thái token sau promote DR-EU

Token do EU cluster phát trước khi sự cố **vẫn hợp lệ** trên DR-EU sau khi promote. Client EU **không cần re-authenticate**.

Lý do: DR-EU liên tục nhận replicate token từ EU cluster. Sau promote, DR-EU có đầy đủ thông tin token đó và công nhận nó là hợp lệ — cho đến khi TTL tự nhiên hết hạn.

### (c) Vai trò của DR-EU sau promote

Sau khi được promote, DR-EU:
- Trở thành **Performance secondary mới của Primary US** (tham gia lại performance replication set).
- **Tự động kết nối lại với Primary US** — không cần operator can thiệp thủ công cho bước này.
- Tiếp tục nhận replicate cấu hình và dữ liệu từ Primary US.
- Phục vụ client EU bình thường (read cục bộ, forward write về Primary US).

---

## Bước 3: Bảng yêu cầu mạng

| Tiêu chí | Port 8200 | Port 8201 |
|---|---|---|
| Dùng cho (mục đích chính) | Client REST API requests; bootstrap lần đầu secondary join | Raft consensus; replication traffic; RPC request forwarding |
| Layer 7 LB (AWS ALB, Nginx HTTP) | Cho phép | **Cam tuyet doi** |
| Layer 4 LB (AWS NLB, HAProxy tcp) | Cho phép | Cho phep (bat buoc) |
| TLS termination tại LB | Cho phép | **Cam — TLS passthrough bat buoc** |
| Hậu quả nếu dùng sai loại LB | Hoạt động bình thường với Layer 7 | Layer 7 phá vỡ mTLS handshake → replication thất bại với lỗi TLS khó debug |

**Lý do cấm Layer 7 cho port 8201**: gRPC/RPC sử dụng HTTP/2 multiplexing và mTLS xác thực ở tầng transport. Layer 7 LB terminate TLS trước khi forward — điều này phá vỡ mTLS. Lỗi thường xuất hiện dạng `transport: authentication handshake failed` hoặc `tls: bad certificate` — rất khó liên kết nguyên nhân đến cấu hình LB.

---

## Bước 4: Khám phá API replication trên Vault OSS

### Các lệnh cần chạy

```bash
# 4a. Trạng thái replication tổng hợp
vault read sys/replication/status

# 4b. Trạng thái DR chi tiết
vault read sys/replication/dr/status

# 4c. Trạng thái Performance chi tiết
vault read sys/replication/performance/status
```

### Kết quả mẫu trên Vault OSS (định dạng JSON)

```bash
vault read -format=json sys/replication/status
```

Output sẽ có dạng:
```json
{
  "request_id": "...",
  "data": {
    "dr": {
      "mode": "disabled"
    },
    "performance": {
      "mode": "disabled"
    }
  }
}
```

### (4d) Giải thích output

**Giá trị `dr.mode` và `performance.mode`**: cả hai đều là `"disabled"`.

**Tại sao Vault OSS trả về `disabled`**: Vault Replication là tính năng Enterprise. Vault OSS không có khả năng kích hoạt replication, nên API trả về `disabled` cho cả DR lẫn Performance mode. Đây là hành vi đúng — không phải lỗi.

**Nếu đây là Vault Enterprise đã bật DR Replication và đây là primary**: `dr.mode` sẽ là `"primary"`. Nếu đây là DR secondary, `dr.mode` sẽ là `"secondary"`. Tương tự với `performance.mode`.

Các giá trị có thể có:
- `disabled` — chưa bật hoặc Vault OSS
- `primary` — cluster này là primary trong replication
- `secondary` — cluster này là secondary trong replication
- `bootstrapping` — đang trong quá trình khởi động replication

### Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
