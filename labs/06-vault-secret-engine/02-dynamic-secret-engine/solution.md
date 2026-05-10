---
title: Đáp án mẫu — Dynamic Secrets Engine
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này thực hành mô hình 2 bước của dynamic secrets engine:

- **Bước 1 (enable + config):** Vault cần thông tin kết nối backend để có thể sinh credential theo yêu cầu. Trong môi trường thực tế, đây là tài khoản admin PostgreSQL với đủ quyền CREATE ROLE. Flag `verify_connection=false` cho phép cấu hình mà không cần kết nối thực sự — hữu ích khi test hoặc CI.
- **Bước 2 (role):** Role ánh xạ use case với cách Vault tạo credential. `creation_statements` chứa SQL template với các placeholder `{{name}}`, `{{password}}`, `{{expiration}}` — Vault sẽ thay thế bằng giá trị thực khi sinh credential.
- **Policy:** Client chỉ cần `read` trên `database/creds/db-readonly`, không cần quyền vào config hay roles.

## Các lệnh

```bash
# Bước 1 — Enable database secrets engine
vault secrets enable database

# Bước 2 — Cấu hình kết nối backend
# verify_connection=false bắt buộc trong môi trường lab không có PostgreSQL
vault write database/config/mydb \
    plugin_name=postgresql-database-plugin \
    connection_url="postgresql://{{username}}:{{password}}@localhost/mydb?sslmode=disable" \
    allowed_roles="db-readonly" \
    username="vault-admin" \
    password="admin-password" \
    verify_connection=false

# Bước 3 — Tạo role db-readonly với TTL
vault write database/roles/db-readonly \
    db_name=mydb \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# Bước 4 — Tạo policy cho client
cat > /tmp/db-client-policy.hcl << 'EOF'
path "database/creds/db-readonly" {
  capabilities = ["read"]
}
EOF

vault policy write db-client /tmp/db-client-policy.hcl

# Bước 5 — Xác nhận cấu hình
# Liệt kê secrets engine
vault secrets list

# Đọc config để kiểm tra
vault read database/config/mydb

# Đọc role để kiểm tra TTL
vault read database/roles/db-readonly
```

## Giải thích từng bước

**Bước 1:** `vault secrets enable database` bật database engine tại path mặc định `database/`. Không cần flag `-path` vì dùng path mặc định theo tên type.

**Bước 2:** Trường `connection_url` dùng placeholder `{{username}}` và `{{password}}` — Vault sẽ thay thế bằng giá trị thực từ trường `username` và `password` khi kết nối. Trường `allowed_roles` giới hạn chỉ role `db-readonly` được phép dùng config này. Flag `verify_connection=false` cho phép Vault lưu config mà không kiểm tra kết nối thực sự.

**Bước 3:** `creation_statements` chứa SQL template với ba placeholder bắt buộc:
- `{{name}}` — tên user ngẫu nhiên Vault sẽ tạo
- `{{password}}` — mật khẩu ngẫu nhiên Vault sẽ sinh
- `{{expiration}}` — thời điểm hết hạn tương ứng với TTL

Trong môi trường thực tế với PostgreSQL đang chạy, bạn có thể đọc credential bằng:
```bash
vault read database/creds/db-readonly
# Sẽ trả về username và password tạm thời, tự xóa sau 1h
```

**Bước 4:** Policy `db-client` chỉ cấp `read` trên đúng path credential — đây là nguyên tắc least privilege. Client không cần và không nên có quyền vào `database/config/` hay `database/roles/`.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
