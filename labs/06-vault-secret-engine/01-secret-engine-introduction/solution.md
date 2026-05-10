---
title: Đáp án mẫu — Vòng đời Secrets Engine
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này thực hành toàn bộ vòng đời của một secrets engine thông qua Vault CLI. Điểm mấu chốt là:

- Flag `-path` khi enable ghi đè tên mount point mặc định.
- Flag `-version=2` khi enable KV engine chỉ định dùng KV v2 (có versioning).
- Lệnh `vault kv put` và `vault kv get` dùng path `<mount>/<secret-path>`.
- Lệnh `tune` nhận PATH (có trailing slash) làm argument, không phải type engine.
- Lệnh `disable` xóa vĩnh viễn — không có cách khôi phục.

## Các lệnh

```bash
# Bước 1 — Bật KV v2 engine tại path tùy chỉnh "demo-secrets/"
vault secrets enable -path=demo-secrets -version=2 kv

# Bước 2 — Liệt kê engine để xác nhận "demo-secrets/" xuất hiện
vault secrets list

# Bước 3 — Ghi secret vào engine và đọc lại để kiểm tra
vault kv put demo-secrets/config api_key="abc123"
vault kv get demo-secrets/config

# Bước 4 — Điều chỉnh default-lease-ttl thành 2 giờ (7200 giây)
# Lưu ý: argument là PATH "demo-secrets/", không phải type "kv"
vault secrets tune -default-lease-ttl=2h demo-secrets/

# Chạy verify.sh để kiểm tra Bước 1-4
bash verify.sh

# Bước 5 — Tắt engine (xóa vĩnh viễn toàn bộ dữ liệu + revoke secrets)
vault secrets disable demo-secrets/

# Xác nhận dữ liệu đã bị xóa — lệnh này sẽ trả về lỗi
vault kv get demo-secrets/config
```

## Giải thích từng bước

**Bước 1:** Lệnh `vault secrets enable -path=demo-secrets -version=2 kv` mount engine type `kv` tại path `demo-secrets/`. Nếu không có flag `-path`, engine sẽ mount tại `kv/` — là tên mặc định theo type. Flag `-version=2` bật KV v2 với versioning.

**Bước 3:** Với KV v2, `vault kv put` ghi secret và tự động tạo version 1. Lệnh `vault kv get` hiển thị nội dung kèm metadata (version, created_time...).

**Bước 4:** Sau khi tune, default-lease-ttl của engine sẽ là 7200 giây (2 giờ). Bạn có thể xác nhận bằng `vault secrets list -detailed` hoặc `vault read sys/mounts/demo-secrets/tune`.

**Bước 5:** Sau disable, path `demo-secrets/` không còn tồn tại. Mọi request đến path này sẽ trả về lỗi "no handler for route". Đây là hành vi không thể đảo ngược.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
