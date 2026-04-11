---
title: "Đáp án mẫu — Thực hành workflow: authenticate, token lookup và revoke"
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này đi qua toàn bộ vòng đời của một Vault token: từ enable auth method,
tạo user, login để nhận token, dùng token đọc secret, đến revoke token và xác
nhận token bị vô hiệu hóa. Đây chính xác là workflow 5 bước trong lý thuyết:
authenticate → token → validate → data → revoke.

Điểm quan trọng cần chú ý:

- Lệnh `vault login` trả về output có nhiều trường. Để lấy giá trị token sạch
  vào biến shell, dùng flag `-format=json` kết hợp với `jq`.
- `VAULT_TOKEN=$ALICE_TOKEN vault ...` ghi đè biến môi trường chỉ cho lệnh đó,
  không ảnh hưởng đến phiên làm việc hiện tại.
- Policy `default` được tạo sẵn trong Vault dev mode với quyền đọc/ghi cơ bản.

## Các lệnh

```bash
# Bước 1 — kiểm tra trạng thái Vault dev server
vault status

# Bước 2 — enable auth method userpass
# Nếu đã enable rồi, lệnh này sẽ báo lỗi "path is already in use" — bỏ qua
vault auth enable userpass

# Bước 3 — tạo user alice với password và policy default
vault write auth/userpass/users/alice \
  password=alice-password \
  policies=default

# Bước 4 — login bằng alice và lưu token vào biến ALICE_TOKEN
ALICE_TOKEN=$(vault login \
  -method=userpass \
  -format=json \
  username=alice \
  password=alice-password \
  | jq -r '.auth.client_token')

echo "Token của alice: $ALICE_TOKEN"

# Bước 5 — xem chi tiết token của alice (TTL, policies, accessor)
vault token lookup "$ALICE_TOKEN"

# Hoặc dùng cách ghi đè VAULT_TOKEN cho lệnh đó:
# VAULT_TOKEN="$ALICE_TOKEN" vault token lookup

# Bước 6 — kiểm tra capabilities của token alice tại path secret/data/myapp/config
vault token capabilities "$ALICE_TOKEN" secret/data/myapp/config

# Bước 7a — dùng root token ghi secret (VAULT_TOKEN=root là mặc định trong Codespace)
vault kv put secret/myapp/config env=production

# Bước 7b — dùng token alice đọc lại secret
VAULT_TOKEN="$ALICE_TOKEN" vault kv get secret/myapp/config

# Bước 8a — revoke token của alice (dùng root token)
vault token revoke "$ALICE_TOKEN"

# Bước 8b — thử dùng token alice sau khi đã revoke — phải nhận lỗi
VAULT_TOKEN="$ALICE_TOKEN" vault token lookup
# Output mong đợi: Error looking up token: ... * bad token
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
