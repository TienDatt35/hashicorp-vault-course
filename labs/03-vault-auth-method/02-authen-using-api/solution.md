---
title: Đáp án mẫu — Xác thực vào Vault bằng API
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này minh họa sự khác biệt cốt lõi giữa xác thực qua CLI và qua API: khi dùng API, không có token helper tự động lưu token. Bạn phải gọi login endpoint, parse JSON response để lấy `auth.client_token`, rồi truyền thủ công vào header `X-Vault-Token` cho mọi request tiếp theo.

Toàn bộ luồng này là nền tảng của mọi ứng dụng, script automation, và CI/CD pipeline tích hợp với Vault.

## Các lệnh

```bash
# ============================================================
# Bước 1 — Enable userpass auth method và tạo user alice
# ============================================================

# Enable userpass (dùng root token mặc định trong dev server)
vault auth enable userpass

# Tạo user alice với password vault123 và policy default
vault write auth/userpass/users/alice \
  password="vault123" \
  policies="default"

# Xác nhận user đã tạo
vault read auth/userpass/users/alice


# ============================================================
# Bước 2 — Gọi login API và quan sát JSON response đầy đủ
# ============================================================

# Gọi login endpoint — xem toàn bộ response không parse
curl -s \
  --request POST \
  --data '{"password": "vault123"}' \
  http://127.0.0.1:8200/v1/auth/userpass/login/alice

# Response sẽ có dạng:
# {
#   "request_id": "...",
#   "auth": {
#     "client_token": "hvs.CAESIJye...",   <-- đây là token cần lấy
#     "accessor": "...",
#     "policies": ["default"],
#     "lease_duration": 2764800,
#     "renewable": true,
#     ...
#   },
#   "lease_id": "",                          <-- chuỗi rỗng, không phải token
#   "data": null,
#   ...
# }
#
# Quan sát:
# - Token nằm trong auth.client_token (prefix hvs.)
# - lease_id ở root level là "" — không phải token
# - lease_duration = 2764800 giây = 32 ngày (TTL mặc định của userpass)


# ============================================================
# Bước 3 — Parse và lưu token vào VAULT_TOKEN
# ============================================================

# Dùng jq để lấy chính xác .auth.client_token
export VAULT_TOKEN=$(curl -s \
  --request POST \
  --data '{"password": "vault123"}' \
  http://127.0.0.1:8200/v1/auth/userpass/login/alice \
  | jq -r '.auth.client_token')

# Kiểm tra token đã lưu — phải bắt đầu bằng "hvs."
echo "Token của alice: $VAULT_TOKEN"


# ============================================================
# Bước 4 — Dùng token gọi API lookup-self
# ============================================================

# Gọi lookup-self với header X-Vault-Token
curl -s \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  http://127.0.0.1:8200/v1/auth/token/lookup-self \
  | jq .

# Response sẽ có trường data.policies = ["default"]
# và data.display_name = "userpass-alice"


# ============================================================
# Bước 5 — Tạo KV secret bằng root token
# ============================================================

# Đặt lại về root token để có quyền ghi
export VAULT_TOKEN=root

# Tạo secret tại secret/data/hello
# KV v2: body phải là {"data": {...}} — không phải {"key": "value"} trực tiếp
curl -s \
  --request POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  --data '{"data": {"message": "xin chao"}}' \
  http://127.0.0.1:8200/v1/secret/data/hello \
  | jq .

# Xác nhận secret đã tạo
curl -s \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  http://127.0.0.1:8200/v1/secret/data/hello \
  | jq '.data.data'
# Kết quả: {"message": "xin chao"}


# ============================================================
# Bước 6 — Đọc secret bằng token của alice
# ============================================================

# Lấy lại token của alice (đã bị ghi đè ở bước 5)
export VAULT_TOKEN=$(curl -s \
  --request POST \
  --data '{"password": "vault123"}' \
  http://127.0.0.1:8200/v1/auth/userpass/login/alice \
  | jq -r '.auth.client_token')

# Thử đọc secret bằng token của alice
curl -s \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  http://127.0.0.1:8200/v1/secret/data/hello

# Lưu ý: alice có policy "default". Policy default trong dev server
# không cấp quyền đọc KV secrets theo mặc định, nên có thể nhận 403.
# Trong môi trường thực tế, bạn cần tạo policy riêng và gán cho alice.
# Để bài lab đơn giản, bước này chủ yếu để quan sát behavior.


# ============================================================
# Bước 7 — Gọi API không có token
# ============================================================

# Gọi không có header X-Vault-Token — quan sát 403
curl -s \
  http://127.0.0.1:8200/v1/auth/token/lookup-self

# Response:
# {"errors":["missing client token"]}
# HTTP status: 403

# Kiểm tra HTTP status code cụ thể
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  http://127.0.0.1:8200/v1/auth/token/lookup-self
# In ra: HTTP Status: 403


# ============================================================
# Bước 8 — Dùng Authorization: Bearer thay X-Vault-Token
# ============================================================

# Lấy lại token của alice
export ALICE_TOKEN=$(curl -s \
  --request POST \
  --data '{"password": "vault123"}' \
  http://127.0.0.1:8200/v1/auth/userpass/login/alice \
  | jq -r '.auth.client_token')

# Gọi với Authorization: Bearer — tương đương X-Vault-Token
curl -s \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  http://127.0.0.1:8200/v1/auth/token/lookup-self \
  | jq .data.display_name

# Kết quả: "userpass-alice" — giống hệt khi dùng X-Vault-Token
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
