---
title: Đáp án mẫu — Khám phá trạng thái Replication trên Vault OSS
---

# Đáp án mẫu

> Đây là lời giải chuẩn cho bài thực hành. Vì bài này dùng Vault OSS dev
> server, kết quả của bạn sẽ giống hệt — `bash verify.sh` báo `[PASS]` cho
> mọi kiểm tra là thành công.

## Bước 1: Kiểm tra trạng thái replication tổng quát

```bash
vault read sys/replication/status
```

Output trên Vault OSS:

```
Key                            Value
---                            -----
dr.mode                        disabled
dr.secondary_id                n/a
dr.state                       idle
performance.mode               disabled
performance.secondary_id       n/a
performance.state              idle
```

**Giải thích từng field:**

- `dr.mode` = `disabled`: DR Replication không được bật. Trên Vault Enterprise,
  giá trị có thể là `primary`, `secondary`, hoặc `bootstrapping`.
- `performance.mode` = `disabled`: Performance Replication không được bật. Tương
  tự, trên Enterprise có thể là `primary` hoặc `secondary`.
- `dr.state` = `idle`: cluster không đang trong quá trình replication nào. Khi
  replication đang chạy, state có thể là `stream-wals` (đang nhận WAL log) hoặc
  `merkle-diff` (đang tính toán diff để sync).
- `dr.secondary_id` = `n/a`: cluster này không phải secondary nên không có ID.
- `cluster_id`: trong Vault OSS dev mode, cluster ID có thể không xuất hiện hoặc
  là một UUID ngắn. Trong Enterprise, đây là UUID dùng để định danh cluster trong
  replication group.

**Tại sao Vault OSS trả về `disabled`?**

Vault OSS không hỗ trợ Replication. API endpoint `sys/replication/status` tồn
tại trên Vault OSS để tương thích, nhưng luôn trả về `disabled` cho cả hai loại.
Đây là hành vi đúng, không phải lỗi.

## Bước 2: Phân tích output chi tiết theo từng loại

```bash
vault read sys/replication/dr/status
```

Output:

```
Key     Value
---     -----
mode    disabled
state   idle
```

```bash
vault read sys/replication/performance/status
```

Output:

```
Key     Value
---     -----
mode    disabled
state   idle
```

**Sự khác biệt giữa `mode` và `state`:**

- `mode` mô tả **vai trò** của cluster trong replication: `primary`, `secondary`,
  hoặc `disabled`. Đây là cấu hình tĩnh.
- `state` mô tả **trạng thái hoạt động hiện tại**: `idle` (không làm gì),
  `stream-wals` (đang nhận WAL log từ primary), hoặc `merkle-diff` (đang tính
  toán diff để đồng bộ). Đây là trạng thái động, thay đổi theo thời gian.

## Bước 3: Đáp án cho 3 tình huống

**Tình huống A — Giảm latency cho nhóm châu Âu:**

Dùng **Performance Replication**. Tạo một Performance secondary cluster ở châu
Âu. Secondary này sẽ phục vụ read cục bộ cho nhóm châu Âu — không cần gọi về
Singapore. Write vẫn được forward về primary Singapore trong suốt, nên ứng dụng
không cần thay đổi code.

Lưu ý: sau khi bật Performance Replication, ứng dụng ở châu Âu cần authenticate
vào Performance secondary châu Âu để nhận token từ cluster đó. Token từ cluster
Singapore không dùng được trên secondary châu Âu.

**Tình huống B — Warm standby khi Singapore mất điện, không re-auth:**

Dùng **DR Replication**. Tạo một DR secondary cluster ở data center dự phòng
(ví dụ: Tokyo hoặc Sydney). DR secondary nhận toàn bộ dữ liệu từ Singapore, bao
gồm cả token và lease.

Khi Singapore mất điện, thực hiện quy trình promote DR secondary (5 bước). Sau
khi promote, toàn bộ token hiện tại của ứng dụng vẫn hợp lệ — đây là lý do yêu
cầu "không cần đăng nhập lại" được đáp ứng.

Bạn cần chuẩn bị sẵn **DR Operation Token** trước khi có sự cố. Không có token
này, quy trình promote phức tạp hơn nhiều.

**Tình huống C — Kết hợp scale đa vùng và DR:**

Dùng **kết hợp cả DR lẫn Performance Replication** trên cùng primary cluster:

- 5 Performance secondary ở 5 văn phòng để phục vụ read cục bộ, giảm latency.
- 1 hoặc nhiều DR secondary ở data center dự phòng để phòng thảm họa.

Vault Enterprise hỗ trợ kết hợp cả hai loại replication trên cùng một cluster.
Primary chỉ cần cấu hình một lần cho mỗi loại, các secondary đăng ký với primary
theo đúng loại của mình.

## Bước 4: So sánh output format

```bash
vault read sys/replication/status
vault read -format=json sys/replication/status
```

Format mặc định (tabular) dễ đọc khi xem trực tiếp. Format JSON hữu ích hơn
trong script tự động hóa vì có thể dùng `jq` để extract field cụ thể:

```bash
# Lấy giá trị dr.mode bằng jq
vault read -format=json sys/replication/status | jq -r '.data["dr.mode"]'

# Hoặc dùng vault read -field
vault read -field="dr.mode" sys/replication/status
```

Trong môi trường production, script monitoring thường dùng JSON format để kiểm
tra `dr.mode` và `performance.mode` có đúng giá trị mong đợi hay không.

## Tại sao không thể demo thực tế với Vault OSS

Vault OSS không cho phép bật replication — lệnh `vault write sys/replication/dr/primary/enable`
sẽ trả về lỗi:

```
Error writing data to sys/replication/dr/primary/enable: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/sys/replication/dr/primary/enable
Code: 400. Errors:

* replication is not supported by OSS builds
```

Để thực hành với replication thực sự, bạn cần một trong:

- Vault Enterprise với license (có thể dùng license trial 30 ngày từ HashiCorp).
- HCP Vault Dedicated cluster (tính phí theo giờ).
- Vault Enterprise trong môi trường lab/sandbox của tổ chức bạn.

Các tutorial chính thức của HashiCorp tại
[developer.hashicorp.com/vault/tutorials/enterprise](https://developer.hashicorp.com/vault/tutorials/enterprise)
cung cấp môi trường sandbox để thực hành miễn phí.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
