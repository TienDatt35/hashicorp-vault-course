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
- Policy `default` **không** cấp quyền truy cập `secret/data/myapp/config` —
  bạn phải tạo policy riêng và gán cho alice. Token cũ không tự cập nhật khi
  policy thay đổi, nên cần login lại để nhận token mới mang policy đó.

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
# Kết quả kỳ vọng: "deny" — alice chỉ có policy default, chưa có quyền ở path này
vault token capabilities "$ALICE_TOKEN" secret/data/myapp/config

# Bước 7 — tạo policy myapp-reader và gán cho alice
vault policy write myapp-reader - <<EOF
path "secret/data/myapp/config" {
  capabilities = ["read", "list"]
}
EOF

# Cập nhật user alice: gán cả default lẫn policy mới
vault write auth/userpass/users/alice \
  password=alice-password \
  policies=default,myapp-reader

# Login lại để nhận token mới có chứa policy myapp-reader
ALICE_TOKEN=$(vault login \
  -method=userpass \
  -format=json \
  username=alice \
  password=alice-password \
  | jq -r '.auth.client_token')

echo "Token mới của alice: $ALICE_TOKEN"

# Xác nhận alice đã có capability read
vault token capabilities "$ALICE_TOKEN" secret/data/myapp/config
# Output mong đợi: read, list

# Bước 8a — dùng root token ghi secret (VAULT_TOKEN=root là mặc định trong Codespace)
vault kv put secret/myapp/config env=production

# Bước 8b — dùng token alice đọc lại secret
VAULT_TOKEN="$ALICE_TOKEN" vault kv get secret/myapp/config

# Bước 9a — revoke token của alice (dùng root token)
vault token revoke "$ALICE_TOKEN"

# Bước 9b — thử dùng token alice sau khi đã revoke — phải nhận lỗi
VAULT_TOKEN="$ALICE_TOKEN" vault token lookup
# Output mong đợi: Error looking up token: ... * bad token
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.

---

## Khám phá thêm — lệnh mẫu cho UI và HTTP API

Phần này không có trong `verify.sh`. Chạy sau khi đã hoàn thành 9 bước chính.

### Khám phá B — HTTP API bằng curl

```bash
# Cần lấy lại ALICE_TOKEN vì đã revoke ở bước 9
ALICE_TOKEN=$(vault login \
  -method=userpass -format=json \
  username=alice password=alice-password \
  | jq -r '.auth.client_token')

# B1 — kiểm tra health (không cần token)
curl -s $VAULT_ADDR/v1/sys/health | jq .

# B2 — đọc secret bằng API với root token
curl -s \
  -H "X-Vault-Token: root" \
  $VAULT_ADDR/v1/secret/data/myapp/config | jq .data.data

# B3 — lookup token của alice qua API
curl -s \
  -H "X-Vault-Token: root" \
  --request POST \
  --data "{\"token\": \"$ALICE_TOKEN\"}" \
  $VAULT_ADDR/v1/auth/token/lookup | jq '{policies: .data.policies, ttl: .data.ttl}'

# B4 — kiểm tra capabilities qua API
curl -s \
  -H "X-Vault-Token: root" \
  --request POST \
  --data "{\"token\": \"$ALICE_TOKEN\", \"path\": \"secret/data/myapp/config\"}" \
  $VAULT_ADDR/v1/sys/capabilities | jq .
```

So sánh output của từng lệnh curl với lệnh CLI tương ứng — chúng trả về cùng
một dữ liệu vì CLI chỉ là wrapper gọi HTTP API.
