---
title: Userpass Auth Method — Đáp án mẫu
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này đi theo vòng đời hoàn chỉnh của userpass auth method: bật,
tạo user, đăng nhập bằng CLI để nhận token, kiểm tra token qua accessor, rồi
lặp lại toàn bộ quy trình đăng nhập bằng HTTP API. Phần API là nền tảng cho mọi
automation script và microservice tích hợp với Vault.

Điểm mấu chốt: khi dùng API, không có token helper tự động lưu token — bạn
phải tự parse `auth.client_token` từ JSON response và tự quản lý nó.

## Các lệnh

```bash
# ============================================================
# Phần 1 — Quản lý userpass qua CLI
# ============================================================

# Bước 1 — Xem auth methods mặc định
# token/ luôn có sẵn và không thể disable
vault auth list

# Bước 2 — Bật userpass auth method
vault auth enable userpass

# Xác nhận userpass đã xuất hiện
vault auth list

# Bước 3 — Tạo user alice với password vault123 và policy default
vault write auth/userpass/users/alice \
  password=vault123 \
  policies=default

# Bước 4 — Đăng nhập bằng CLI
# vault login tự lưu token vào ~/.vault-token
vault login -method=userpass username=alice password=vault123

# Bước 5 — Xem chi tiết token hiện tại
vault token lookup

# Lưu accessor vào biến để dùng ở bước 6
ACCESSOR=$(vault token lookup -format=json | jq -r '.data.accessor')
echo "Accessor: $ACCESSOR"

# Bước 6 — Tra cứu token qua accessor (dùng root token vì alice không có quyền)
# Lưu ý: trường "id" sẽ là "n/a" — đây là tính năng bảo mật
VAULT_TOKEN=root vault token lookup -accessor "$ACCESSOR"


# ============================================================
# Phần 2 — Xác thực qua HTTP API
# ============================================================

# Trở về root token
export VAULT_TOKEN=root

# Bước 7 — Gọi login API, xem toàn bộ JSON response
curl -s \
  --request POST \
  --data '{"password": "vault123"}' \
  http://127.0.0.1:8200/v1/auth/userpass/login/alice

# Quan sát:
# - Token nằm trong auth.client_token (bắt đầu bằng hvs.)
# - lease_id ở root level là "" — không phải token
# - lease_duration = 2764800 giây = 32 ngày (TTL mặc định của userpass)

# Bước 8 — Parse token và lưu vào VAULT_TOKEN
export VAULT_TOKEN=$(curl -s \
  --request POST \
  --data '{"password": "vault123"}' \
  http://127.0.0.1:8200/v1/auth/userpass/login/alice \
  | jq -r '.auth.client_token')

# Kiểm tra token — phải bắt đầu bằng "hvs."
echo "Token của alice: $VAULT_TOKEN"

# Bước 9 — Dùng token gọi API lookup-self
curl -s \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  http://127.0.0.1:8200/v1/auth/token/lookup-self \
  | jq .

# Response có trường data.policies = ["default"]
# và data.display_name = "userpass-alice"

# Bước 10 — Gọi API không có token, quan sát 403
curl -s http://127.0.0.1:8200/v1/auth/token/lookup-self
# Response: {"errors":["missing client token"]}

# Kiểm tra HTTP status code
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  http://127.0.0.1:8200/v1/auth/token/lookup-self
# In ra: HTTP Status: 403

# Bước 11 — Dùng Authorization: Bearer thay vì X-Vault-Token
curl -s \
  -H "Authorization: Bearer $VAULT_TOKEN" \
  http://127.0.0.1:8200/v1/auth/token/lookup-self \
  | jq .data.display_name
# Kết quả: "userpass-alice" — giống hệt khi dùng X-Vault-Token

# Bước 12 — Disable userpass auth method
export VAULT_TOKEN=root
vault auth disable userpass

# Xác nhận userpass không còn trong danh sách
vault auth list
```

## Output mẫu bước 4 (CLI login)

```
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
token                  hvs.CAESIB...
token_accessor         abc123def456...
token_duration         768h
token_renewable        true
token_policies         ["default"]
identity_policies      []
policies               ["default"]
token_meta_username    alice
```

## Output mẫu bước 6 (lookup bằng accessor)

```
Key                 Value
---                 -----
accessor            abc123def456...
creation_time       1712345678
display_name        userpass-alice
id                  n/a
issue_time          2026-04-12T...
meta                map[username:alice]
policies            [default]
renewable           true
ttl                 767h59m...
type                service
```

Lưu ý: trường `id` có giá trị `n/a` khi lookup bằng accessor — bạn quản lý được
token mà không bao giờ thấy giá trị token thực.

## Kiểm tra lại

Chạy verify **trước bước 12** (khi userpass còn đang bật và alice còn tồn tại):

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
