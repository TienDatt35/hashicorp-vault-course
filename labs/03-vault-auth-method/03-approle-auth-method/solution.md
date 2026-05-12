---
title: Đáp án mẫu — Thực hành AppRole Auth Method
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

AppRole sử dụng hai thông tin tách biệt để xác thực: RoleID (không bí mật) và
SecretID (bí mật có TTL và giới hạn số lần dùng). Bài thực hành này mô phỏng
toàn bộ vòng đời: bật auth method, tạo role, sinh credential, login qua CLI
và API, rồi kiểm chứng rằng SecretID bị vô hiệu sau khi dùng đủ 5 lần. Điều
này tương ứng trực tiếp với cách các hệ thống tự động (CI/CD, Vault Agent) làm
việc trong thực tế.

## Các lệnh

```bash
# Bước 1 — Bật AppRole auth method
vault auth enable approle

# Bước 2 — Tạo role my-app
vault write auth/approle/role/my-app \
    token_policies="default" \
    token_ttl=1h \
    secret_id_num_uses=5 \
    secret_id_ttl=30m

# Bước 3 — Đọc RoleID và lưu vào biến
ROLE_ID=$(vault read -field=role_id auth/approle/role/my-app/role-id)
echo "ROLE_ID: $ROLE_ID"

# Bước 4 — Sinh SecretID (Pull mode) và lưu vào biến
# -force bắt buộc vì endpoint không nhận body dữ liệu
SECRET_ID=$(vault write -force -field=secret_id auth/approle/role/my-app/secret-id)
echo "SECRET_ID: $SECRET_ID"

# Bước 5 — Login bằng AppRole qua CLI (đây là lần dùng thứ 1 của SECRET_ID)
vault write auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID"

# Bước 6 — Sinh SecretID mới để dùng qua API
SECRET_ID2=$(vault write -force -field=secret_id auth/approle/role/my-app/secret-id)

# Login qua API và lấy token
API_TOKEN=$(curl -s \
    --request POST \
    --data "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID2\"}" \
    http://127.0.0.1:8200/v1/auth/approle/login \
  | jq -r '.auth.client_token')
echo "API_TOKEN: $API_TOKEN"

# Bước 7 — Dùng token vừa lấy để tra cứu thông tin
vault token lookup "$API_TOKEN"

# Hoặc qua API:
# curl -H "X-Vault-Token: $API_TOKEN" http://127.0.0.1:8200/v1/auth/token/lookup-self

# Bước 8 — Kiểm chứng giới hạn secret_id_num_uses=5
# Sinh SecretID mới để đếm đủ 5 lần
SECRET_ID3=$(vault write -force -field=secret_id auth/approle/role/my-app/secret-id)

# Lần 1 đến 5 — phải thành công
for i in 1 2 3 4 5; do
    echo "--- Login lần $i ---"
    vault write auth/approle/login \
        role_id="$ROLE_ID" \
        secret_id="$SECRET_ID3"
done

# Lần 6 — phải thất bại
echo "--- Login lần 6 (phải thất bại) ---"
vault write auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID3" \
  && echo "LOGIN THANH CONG - SAI! Secret ID nay phai het han" \
  || echo "Login that bai dung nhu mong doi - SecretID da het so lan dung"

# Bước 9 — Sinh SecretID mới và login lại thành công
SECRET_ID_NEW=$(vault write -force -field=secret_id auth/approle/role/my-app/secret-id)
vault write auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID_NEW"
echo "Login thanh cong voi SecretID moi"
```

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
