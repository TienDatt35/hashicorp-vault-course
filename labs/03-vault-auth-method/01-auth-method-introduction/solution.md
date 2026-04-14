---
title: Giới thiệu Auth Methods — Đáp án mẫu
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác
> cũng đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này đi theo vòng đời hoàn chỉnh của một auth method: bật
(enable), cấu hình user, authenticate để nhận token, kiểm tra token và
accessor, và cuối cùng tắt (disable). Đây là quy trình bạn sẽ lặp lại nhiều
lần khi quản lý Vault trong thực tế.

Mấu chốt cần ghi nhớ: sau khi `vault login` thành công, Vault trả về
`client_token` — từ đó trở đi bạn dùng token đó cho mọi request, không cần
gửi lại username/password.

## Các lệnh

```bash
# Bước 1 — Xem auth methods mặc định
# token/ luôn có sẵn và không thể disable
vault auth list

# Bước 2 — Bật userpass auth method
vault auth enable userpass

# Xác nhận userpass đã xuất hiện trong danh sách
vault auth list

# Bước 3 — Tạo user alice với mật khẩu và policy default
vault write auth/userpass/users/alice \
  password=vault123 \
  policies=default

# Bước 4 — Đăng nhập bằng alice, quan sát output
# Vault in ra token, policies, ttl sau khi login thành công
vault login -method=userpass username=alice password=vault123

# Bước 5 — Kiểm tra chi tiết token hiện tại
# Sau khi login, VAULT_TOKEN đã được cập nhật thành token của alice
vault token lookup

# Lưu accessor vào biến để dùng ở bước 6
ACCESSOR=$(vault token lookup -format=json | jq -r '.data.accessor')
echo "Accessor: $ACCESSOR"

# Bước 6 — Tra cứu token qua accessor (không cần biết token thực)
# Dùng root token để lookup vì alice không có quyền lookup bằng accessor
VAULT_TOKEN=root vault token lookup -accessor "$ACCESSOR"

# Bước 7 — Gọi Vault không có token, quan sát 403
curl -s http://127.0.0.1:8200/v1/auth/token/lookup-self
# Kết quả mong đợi: {"errors":["missing client token"]}

# Hoặc dùng CLI với token rỗng
VAULT_TOKEN="" vault token lookup 2>&1 || true

# Bước 8 — Disable userpass auth method
# Lấy lại quyền root trước khi disable
export VAULT_TOKEN=root
vault auth disable userpass

# Xác nhận userpass không còn trong danh sách
vault auth list
```

## Output mẫu cho bước 4

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

## Output mẫu cho bước 6 (lookup bằng accessor)

```
Key                 Value
---                 -----
accessor            abc123def456...
creation_time       1712345678
display_name        userpass-alice
entity_id           7d2e3c1a-...
expire_time         2026-05-12T...
explicit_max_ttl    0s
id                  n/a
issue_time          2026-04-12T...
meta                map[username:alice]
num_uses            0
orphan              true
path                auth/userpass/login/alice
policies            [default]
renewable           true
ttl                 767h59m...
type                service
```

Lưu ý trường `id` có giá trị `n/a` khi lookup bằng accessor — đây là tính
năng bảo mật: bạn quản lý được token mà không bao giờ thấy giá trị token thực.

## Kiểm tra lại

Chạy verify trước bước 8 (khi userpass còn đang bật và alice còn tồn tại):

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
