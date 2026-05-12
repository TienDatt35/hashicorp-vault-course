---
title: Đáp án mẫu — Khám phá Vault dev server và token cơ bản
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này đi qua hai nhóm thao tác căn bản:

1. **Kiểm tra và xác thực** — kiểm tra trạng thái server, đăng nhập bằng root
   token để xác lập phiên làm việc.

2. **Khám phá cấu hình Vault** — liệt kê secrets engine và auth method để hiểu
   những gì đang được bật mặc định trong chế độ dev. Đây là bước quan trọng
   trước khi bắt đầu làm việc với bất kỳ Vault nào (dev hay production).

## Các lệnh

```bash
# Bước 1 — Kiểm tra Vault đang chạy
vault status

# Bước 2 — Xác thực bằng root token
vault login root

# Bước 3 — Xem danh sách secrets engine
vault secrets list
# Engine mặc định trong dev mode: cubbyhole/, identity/, secret/, sys/

# Bước 4 — Xem danh sách auth method
vault auth list
# Auth method mặc định: token/

# Bước 5 — Bật KV v2 tại path kv/
vault secrets enable -version=2 kv

# Xác nhận kv/ đã xuất hiện
vault secrets list

# Bước 6 — Ghi secret đầu tiên
vault kv put kv/app/db username=admin password=s3cret-v1

# Đọc lại để xác nhận
vault kv get kv/app/db
```

## Kiểm tra lại

```sh
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
