---
title: Đáp án mẫu — Dynamic Secrets Engine
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này thực hành toàn bộ vòng đời của dynamic secrets engine:

- **Bước 0 (Docker):** PostgreSQL chạy trong container cục bộ, đóng vai trò database backend thật.
- **Bước 1–2 (enable + config):** Vault lưu thông tin kết nối và xác minh có thể kết nối tới DB.
- **Bước 3 (role):** Role ánh xạ use case với SQL template. Các placeholder `{{name}}`, `{{password}}`, `{{expiration}}` được Vault thay thế khi sinh credential.
- **Bước 4 (policy):** Client chỉ cần `read` trên `database/creds/db-readonly`, không cần quyền vào config hay roles.
- **Bước 6 (credential):** Mỗi lần gọi `vault read database/creds/db-readonly` Vault chạy câu SQL tạo một PostgreSQL user mới, trả về username/password kèm `lease_id`. Khi lease hết hạn hoặc bị revoke, Vault chạy câu SQL xóa user đó.

## Các lệnh

```bash
# ========================================
# Bước 0 — Khởi động PostgreSQL bằng Docker
# ========================================
docker run -d \
  --name postgres-lab \
  -e POSTGRES_USER=vault-admin \
  -e POSTGRES_PASSWORD=admin-password \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  postgres:15-alpine

# Chờ PostgreSQL sẵn sàng nhận kết nối
until docker exec postgres-lab pg_isready -U vault-admin 2>/dev/null; do
  sleep 1
done
echo "PostgreSQL sẵn sàng."

# ========================================
# Bước 1 — Enable database secrets engine
# ========================================
vault secrets enable database

# ========================================
# Bước 2 — Cấu hình kết nối backend
# ========================================
# Không cần verify_connection=false vì đã có database thật
vault write database/config/mydb \
    plugin_name=postgresql-database-plugin \
    connection_url="postgresql://{{username}}:{{password}}@localhost:5432/mydb?sslmode=disable" \
    allowed_roles="db-readonly" \
    username="vault-admin" \
    password="admin-password"

# ========================================
# Bước 3 — Tạo role db-readonly với TTL
# ========================================
vault write database/roles/db-readonly \
    db_name=mydb \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# ========================================
# Bước 4 — Tạo policy cho client
# ========================================
cat > /tmp/db-client-policy.hcl << 'EOF'
path "database/creds/db-readonly" {
  capabilities = ["read"]
}
EOF

vault policy write db-client /tmp/db-client-policy.hcl

# ========================================
# Bước 5 — Xác nhận cấu hình
# ========================================
vault read database/config/mydb
vault read database/roles/db-readonly

# ========================================
# Bước 6 — Tạo credential thật
# ========================================
vault read database/creds/db-readonly
# Output:
#   Key                Value
#   ---                -----
#   lease_id           database/creds/db-readonly/AbCdEf...
#   lease_duration     1h
#   lease_renewable    true
#   password           A1b2C3d4-...
#   username           v-root-db-readon-...

# Chạy lần hai để thấy username/password khác nhau hoàn toàn
vault read database/creds/db-readonly

# Revoke thủ công một lease (thay <lease_id> bằng giá trị thật)
# vault lease revoke <lease_id>
```

## Giải thích từng bước

**Bước 0:** `docker run` tạo container PostgreSQL với `vault-admin` là superuser — đủ quyền để chạy `CREATE ROLE` khi Vault sinh credential. Flag `-p 5432:5432` expose port để Vault kết nối qua `localhost:5432`.

**Bước 2:** Trường `connection_url` dùng placeholder `{{username}}` và `{{password}}` — Vault thay bằng giá trị thực từ `username`/`password` khi kiểm tra kết nối. Lần này bỏ `verify_connection=false` để Vault thật sự kết nối và xác minh ngay.

**Bước 3:** Ba placeholder bắt buộc trong `creation_statements`:
- `{{name}}` — tên user ngẫu nhiên (ví dụ: `v-root-db-readon-AbCdEf`)
- `{{password}}` — mật khẩu ngẫu nhiên
- `{{expiration}}` — thời điểm hết hạn khớp với TTL

**Bước 6:** Vault kết nối PostgreSQL, chạy câu `CREATE ROLE ...`, trả về username/password và một `lease_id`. Khi lease hết hạn (sau 1h) hoặc bị revoke, Vault chạy câu `DROP ROLE` để xóa user khỏi DB — không cần can thiệp thủ công.

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
