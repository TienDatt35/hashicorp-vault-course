---
title: Đáp án mẫu — Thực hành so sánh Static và Platform Auth
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này minh họa hai loại static auth method: AppRole (dành cho machine/workload) và Userpass (dành cho human). Cả hai đều là "static" vì credential được tạo trước và phải quản lý rotation thủ công — khác với AWS/Kubernetes auth nơi platform tự cấp credential ephemeral.

Điểm quan trọng cần quan sát sau khi login:
- Token từ AppRole có `auth.metadata.role_name` = `dev-role` — cho biết role nào đã xác thực.
- Token từ Userpass có `auth.metadata.username` = `alice` — cho biết user nào đã xác thực.
- Cả hai token đều có `policies` chứa `dev-policy` — xác nhận policy được gán đúng.

## Các lệnh

```bash
# Bước 1 — Tạo policy dev-policy
vault policy write dev-policy - <<EOF
path "secret/data/dev/*" {
  capabilities = ["read", "list"]
}
EOF

# Xác nhận policy đã tạo
vault policy read dev-policy


# Bước 2 — Enable và cấu hình AppRole auth

# Enable AppRole auth method
vault auth enable approle

# Tạo role dev-role với policy dev-policy
vault write auth/approle/role/dev-role \
  policies="dev-policy" \
  secret_id_ttl="24h" \
  token_ttl="1h"

# Lấy role-id của dev-role
vault read auth/approle/role/dev-role/role-id

# Tạo secret-id mới (lưu lại giá trị secret_id trong output)
vault write -f auth/approle/role/dev-role/secret-id

# Đăng nhập bằng AppRole (thay <ROLE_ID> và <SECRET_ID> bằng giá trị thực)
vault write auth/approle/login \
  role_id="<ROLE_ID>" \
  secret_id="<SECRET_ID>"

# Quan sát output:
# - auth.client_token: token vừa được cấp
# - auth.policies: ["default", "dev-policy"]
# - auth.metadata.role_name: "dev-role"
# - auth.token_type: "service"


# Bước 3 — Enable và cấu hình Userpass auth

# Enable Userpass auth method
vault auth enable userpass

# Tạo user alice với policy dev-policy
vault write auth/userpass/users/alice \
  password="training" \
  policies="dev-policy"

# Đăng nhập bằng user alice
vault write auth/userpass/login/alice \
  password="training"

# Quan sát output và so sánh với AppRole:
# - auth.metadata.username: "alice"
# - auth.policies: ["default", "dev-policy"]
# - auth.token_type: "service"


# Bước 4 — Liệt kê tất cả auth methods
vault auth list

# Output sẽ hiển thị:
# Path        Type        Accessor               Description
# ----        ----        --------               -----------
# approle/    approle     auth_approle_XXXXXXXX  n/a
# token/      token       auth_token_YYYYYYYY    token based credentials
# userpass/   userpass    auth_userpass_ZZZZZZZZ n/a


# Bước 5 — Kiểm tra token capabilities
# Lấy token từ AppRole login và kiểm tra capabilities
APPROLE_TOKEN=$(vault write -format=json auth/approle/login \
  role_id="<ROLE_ID>" \
  secret_id="<SECRET_ID>" \
  | jq -r '.auth.client_token')

VAULT_TOKEN=$APPROLE_TOKEN vault token capabilities secret/data/dev
# Kết quả mong đợi: read, list

# Kiểm tra một path không được phép
VAULT_TOKEN=$APPROLE_TOKEN vault token capabilities secret/data/production
# Kết quả mong đợi: deny
```

## Giải thích chi tiết từng bước

**Policy `dev-policy`**: policy này dùng path `secret/data/dev/*` với wildcard để áp dụng cho mọi sub-path trong `dev/`. Với KV v2, path thực tế là `secret/data/<key>` (có `/data/` ở giữa).

**AppRole — RoleID vs SecretID**: RoleID là public identifier (như username) — bạn có thể hardcode vào config. SecretID là private credential (như password) — phải được inject an toàn, không được commit vào code. `vault write -f` (flag `-f`) dùng để tạo secret-id mà không cần body JSON.

**Userpass — password vs SecretID**: Cả hai đều là static credential, nhưng khác nhau về mục đích: Userpass dành cho human login, AppRole dành cho machine auth.

**`vault auth list`**: lệnh này liệt kê tất cả auth methods đang được enable cùng với `accessor` — identifier duy nhất của mỗi auth mount. Accessor dùng để tạo entity alias và group alias trong Vault Identity system.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
