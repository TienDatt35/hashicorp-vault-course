---
title: Đáp án mẫu — Dynamic Secrets Engine
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này thực hành toàn bộ vòng đời của dynamic secrets engine:

- **Bước 0 (PostgreSQL):** Cài và chạy PostgreSQL trực tiếp trong Codespace (Alpine, không có Docker daemon).
- **Bước 1–2 (enable + config):** Vault lưu thông tin kết nối và xác minh có thể kết nối tới DB.
- **Bước 3 (role):** Role ánh xạ use case với SQL template. Các placeholder `{{name}}`, `{{password}}`, `{{expiration}}` được Vault thay thế khi sinh credential.
- **Bước 4 (policy):** Client chỉ cần `read` trên `database/creds/db-readonly`, không cần quyền vào config hay roles.
- **Bước 6 (credential):** Mỗi lần gọi `vault read database/creds/db-readonly` Vault chạy câu SQL tạo một PostgreSQL user mới, trả về username/password kèm `lease_id`. Khi lease hết hạn hoặc bị revoke, Vault chạy câu SQL xóa user đó.

## Các lệnh

```bash
# ========================================
# Bước 0 — Cài đặt và khởi động PostgreSQL
# ========================================
# Codespace dùng Alpine — cài trực tiếp, không qua Docker
apk add --no-cache postgresql postgresql-client

# Khởi tạo data directory với postgres là OS user
mkdir -p /tmp/pgdata
chown postgres /tmp/pgdata
su postgres -c "initdb -D /tmp/pgdata -U postgres --auth=trust"

# Thêm rule TCP với password (Vault kết nối qua 127.0.0.1, không qua unix socket)
echo "host all all 127.0.0.1/32 md5" >> /tmp/pgdata/pg_hba.conf

# Khởi động PostgreSQL
su postgres -c "pg_ctl -D /tmp/pgdata -l /tmp/pg.log start"

# Chờ sẵn sàng
until pg_isready -h 127.0.0.1 -p 5432 2>/dev/null; do sleep 1; done
echo "PostgreSQL sẵn sàng."

# Tạo role vault-admin (superuser) và database mydb
cat > /tmp/setup.sql << 'SQL'
CREATE ROLE "vault-admin" WITH SUPERUSER LOGIN PASSWORD 'admin-password';
CREATE DATABASE mydb OWNER "vault-admin";
SQL
su postgres -c "psql -f /tmp/setup.sql"

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

**Bước 0:** `apk add postgresql` cài PostgreSQL trong container Alpine. `initdb` phải chạy với OS user `postgres` (PostgreSQL không cho phép init/start với root). Ta tạo `vault-admin` là superuser PostgreSQL riêng biệt với password — đây là tài khoản Vault dùng để kết nối và chạy `CREATE ROLE`. Rule `host ... md5` trong `pg_hba.conf` bắt buộc có vì Vault kết nối qua TCP (127.0.0.1:5432), không qua unix socket.

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
