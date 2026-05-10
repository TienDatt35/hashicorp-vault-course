---
title: Phân tích kiến trúc Vault Replication đa vùng
estMinutes: 20
---

# Phân tích kiến trúc Vault Replication đa vùng

## Mục tiêu

Bài thực hành này giúp bạn củng cố hiểu biết về kiến trúc Vault Replication trong môi trường đa vùng thông qua phân tích tình huống và khám phá API replication trực tiếp trên Vault OSS.

Lưu ý: tính năng Replication chỉ hoạt động đầy đủ trên Vault Enterprise. Trong bài này, bạn sẽ dùng Vault OSS để khám phá cấu trúc API và phân tích kiến trúc dưới dạng bài tập thiết kế.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết `theory.mdx` của bài học này.
- Không cần cài đặt thêm công cụ nào.

## Nhiệm vụ của bạn

### Bước 1: Phân tích tình huống — thiết kế topology

Công ty bạn có văn phòng ở ba vùng: US (trụ sở chính), EU, và APAC. Giám đốc kỹ thuật yêu cầu một kiến trúc Vault đáp ứng:

- Ứng dụng ở EU và APAC đọc secret với latency thấp nhất có thể.
- Mỗi vùng có khả năng phục hồi độc lập khi cluster của vùng đó gặp sự cố.
- Toàn bộ hệ thống có thể phục hồi khi primary chính (US) gặp thảm họa.

Trả lời các câu hỏi sau (viết ra giấy hoặc tạo file ghi chú riêng):

**(a)** Vẽ topology bằng text diagram hoặc mô tả tên từng cluster, loại replication kết nối chúng, và chiều replication (cluster nào là nguồn, cluster nào là đích).

**(b)** Client ở EU nên authenticate với cluster nào? Tại sao không nên authenticate với Primary US?

**(c)** Token được tạo trên EU cluster sẽ được replicate đến những cluster nào trong topology? Cluster nào sẽ KHÔNG nhận token đó?

### Bước 2: Phân tích tình huống failover

Tình huống: EU Performance cluster gặp sự cố phần cứng và không thể khôi phục trong ít nhất 2 giờ. DR-EU đang chạy bình thường với bản sao đầy đủ của EU cluster.

Trả lời các câu hỏi sau:

**(a)** Liệt kê theo thứ tự các bước operator cần thực hiện để khôi phục khả năng phục vụ client EU (không cần lệnh cụ thể, chỉ cần mô tả từng bước và lý do).

**(b)** Sau khi promote DR-EU, trạng thái của các token do EU cluster phát trước khi sự cố là gì? Client EU có cần re-authenticate không?

**(c)** Sau khi promote DR-EU, cluster này sẽ có vai trò gì trong topology? Nó có tự động kết nối lại với Primary US không?

### Bước 3: Phân tích yêu cầu mạng

Đội ngũ hạ tầng hỏi bạn về cấu hình load balancer cho hai port của Vault. Điền vào bảng sau (viết ra giấy hoặc ghi chú riêng):

| Tiêu chí | Port 8200 | Port 8201 |
|---|---|---|
| Dùng cho (mục đích chính) | ? | ? |
| Layer 7 LB (AWS ALB, Nginx HTTP) | Cho phép / Cấm? | Cho phép / Cấm? |
| Layer 4 LB (AWS NLB, HAProxy tcp) | Cho phép / Cấm? | Cho phép / Cấm? |
| TLS termination tại LB | Cho phép / Cấm? | Cho phép / Cấm? |
| Hậu quả nếu dùng sai loại LB | ? | ? |

### Bước 4: Khám phá API replication trên Vault OSS

Vault dev server đang chạy sẵn. Thực hiện các lệnh sau và quan sát kết quả:

**4a.** Kiểm tra trạng thái replication tổng hợp:

```bash
vault read sys/replication/status
```

**4b.** Kiểm tra trạng thái DR replication chi tiết:

```bash
vault read sys/replication/dr/status
```

**4c.** Kiểm tra trạng thái Performance replication chi tiết:

```bash
vault read sys/replication/performance/status
```

**4d.** Quan sát và trả lời:
- Giá trị của trường `dr.mode` và `performance.mode` là gì?
- Tại sao Vault OSS trả về giá trị đó?
- Nếu đây là Vault Enterprise đã bật DR Replication và đây là primary, giá trị `dr.mode` sẽ là gì?

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

Bộ kiểm tra xác nhận bạn đã thực hiện các lệnh ở Bước 4 và Vault trả về kết quả đúng với hành vi của Vault OSS.

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích cho tất cả các bước.
