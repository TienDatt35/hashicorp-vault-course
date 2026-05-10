---
title: Đáp án mẫu — Thiết lập DR Replication
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này dùng Vault OSS (dev server), vốn không hỗ trợ DR Replication.
Mục tiêu là làm quen với các lệnh CLI replication, đọc hiểu output trả về, và
hiểu tại sao Vault OSS trả về lỗi license. Kiến thức này sẽ áp dụng trực tiếp
khi bạn làm việc với Vault Enterprise trong môi trường thực tế.

## Các lệnh

### Bước 1 — Kiểm tra trạng thái DR replication

```bash
# Đọc trạng thái DR replication
vault read sys/replication/dr/status
```

Trên Vault OSS, output trả về:

```
Key     Value
---     -----
mode    disabled
```

Trường `mode: disabled` xác nhận replication chưa được kích hoạt. Trên Vault
Enterprise sau khi activate primary, trường này sẽ là `primary`.

### Bước 2 — Thử kích hoạt DR Primary

```bash
# Thử kích hoạt DR primary
vault write -f sys/replication/dr/primary/enable
```

Vault OSS trả về lỗi tương tự:

```
Error writing data to sys/replication/dr/primary/enable: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/sys/replication/dr/primary/enable
Code: 400. Errors:

* DR Replication is a Vault Enterprise feature
```

Lỗi này xác nhận DR Replication là tính năng Enterprise. Lệnh CLI đúng, chỉ
thiếu license phù hợp.

### Bước 3 — Kiểm tra phiên bản và license

```bash
# Xem thông tin phiên bản Vault
vault version
```

Output dạng:

```
Vault v1.x.x (...)
```

Nếu output không có chữ `+ent` hoặc `+prem`, đây là bản OSS. Để xem chi tiết hơn:

```bash
# Xem thông tin server đầy đủ
vault status
```

Trường `License: License (Enterprise only)` sẽ cho biết trạng thái license.

### Bước 4 — Khám phá endpoint replication

```bash
# Đọc trạng thái tổng quát của replication (bao gồm DR và Performance)
vault read sys/replication/status
```

Trên Vault OSS, output trả về cả DR lẫn Performance đều ở trạng thái `disabled`.
Endpoint `sys/replication/dr/status` vẫn phản hồi (không lỗi 404) vì Vault OSS
vẫn có code path này — chỉ là tính năng bị disable ở mức license.

### Bước 5 — Quy trình 3 bước thiết lập DR Replication

Dưới đây là 3 lệnh đầy đủ để thiết lập DR Replication trên Vault Enterprise:

```bash
# ============================================================
# CHAY TREN CLUSTER A (Primary)
# ============================================================

# Buoc 1 — Kich hoat DR Primary
vault write sys/replication/dr/primary/enable \
  primary_cluster_addr="https://vault-primary.example.com:8201"

# Buoc 2 — Tao Secondary Token (thay "dr-secondary" bang ten dinh danh cua ban)
vault write sys/replication/dr/primary/secondary-token id="dr-secondary"
# Luu wrapping_token tu output — ban can no cho buoc tiep theo

# ============================================================
# CHAY TREN CLUSTER B (Secondary)
# CANH BAO: lenh nay xoa sach du lieu tren Cluster B ngay lap tuc
# ============================================================

# Bước 3 — Kích hoạt DR Secondary (thay token bằng wrapping_token từ bước 2)
vault write sys/replication/dr/secondary/enable \
  token="eyJhbGciOiJFUzUxMiIs..."

# Kiểm tra trạng thái sau khi thiết lập
vault read sys/replication/dr/status
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
