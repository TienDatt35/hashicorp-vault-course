---
title: Đáp án mẫu — Khám phá kiến trúc Vault, thành phần và path-based routing
---

# Đáp án mẫu

> Đây là một cách giải chuẩn. Có thể có nhiều cách khác — miễn là
> `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này đi qua 3 nhóm khái niệm kiến trúc chính:

1. **Storage Backend và trạng thái Vault**: `vault status` cho thấy dev mode
   dùng `inmem` — dữ liệu mất khi restart. Production dùng Raft hoặc Consul.

2. **Path-based routing**: mọi component (secrets engine, auth method) đều được
   mount tại một path. Router dùng prefix để điều hướng. Custom path cho phép
   cùng loại engine chạy tại nhiều path độc lập. Reserved paths (`sys/`,
   `identity/`, `cubbyhole/`, `auth/`) không thể bị ghi đè.

3. **System Backend `sys/`**: tất cả lệnh quản lý (`vault secrets list`,
   `vault auth list`) đều là wrapper gọi `GET /v1/sys/mounts` và
   `GET /v1/sys/auth`. Hiểu `sys/` giúp bạn dùng API trực tiếp khi cần.

## Các lệnh

```bash
# Bước 1 — kiểm tra trạng thái
vault status

# Bước 2 — khám phá secrets engine mặc định
vault secrets list
vault secrets list -detailed
vault read sys/mounts/secret

# Bước 3 — khám phá auth methods
vault auth list
vault auth list -detailed

# Bước 4 — đọc trực tiếp qua sys/
vault read sys/mounts   # tương đương vault secrets list
vault read sys/auth     # tương đương vault auth list

# Bước 5 — enable KV tại custom path
vault secrets enable -version=2 -path=app kv
vault secrets enable -version=2 -path=config kv
vault secrets list
# Kết quả: cả app/ và config/ đều xuất hiện với type=kv

# Bước 6 — kiểm chứng path-based routing
vault kv put app/database password=db-secret
vault kv put config/feature-flags debug=true
vault kv get app/database
# Thấy: password=db-secret — engine tại app/ độc lập với config/
vault kv get config/feature-flags
# Thấy: debug=true

# Bước 7 — enable auth method userpass
vault auth enable userpass
vault write auth/userpass/users/student password=student-pass policies=default
vault auth list
# Thấy: userpass/ xuất hiện trong danh sách

# Bước 8 — kiểm tra reserved paths (cả hai lệnh dưới sẽ thất bại — đây là đúng)
vault secrets enable -path=sys kv
# Lỗi: cannot mount to existing path
vault secrets enable -path=identity kv
# Lỗi: cannot mount to existing path
```

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
