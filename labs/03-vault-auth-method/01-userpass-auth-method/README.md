---
title: Userpass Auth Method
estMinutes: 25
---

# Userpass Auth Method

## Mục tiêu

Sau khi hoàn thành bài thực hành, bạn sẽ biết cách enable userpass auth method,
tạo user, đăng nhập và kiểm tra token bằng **CLI**, sau đó thực hiện lại toàn bộ
quy trình đăng nhập bằng **HTTP API** với `curl` và `jq`.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này — Vault dev server đã được
  khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR` và `VAULT_TOKEN` đã được thiết lập sẵn.
- `curl` và `jq` đã có sẵn trong Codespace.
- Bạn đã đọc bài lý thuyết tương ứng trong
  `site/docs/03-vault-auth-method/02-userpass-auth-method/`.

## Nhiệm vụ của bạn

### Phần 1 — Quản lý userpass qua CLI

**Bước 1 — Xem auth methods mặc định**

Liệt kê tất cả auth methods đang bật trong Vault. Xác nhận auth method nào đã có
sẵn mà không cần bật thêm và tại sao nó không thể bị disable.

**Bước 2 — Enable userpass auth method**

Bật userpass auth method. Sau khi bật, kiểm tra lại danh sách để xác nhận.

**Bước 3 — Tạo người dùng**

Tạo user có tên `alice` trong userpass auth method với mật khẩu `vault123` và
policy `default`.

**Bước 4 — Đăng nhập bằng CLI và quan sát token**

Đăng nhập với tài khoản `alice` bằng userpass auth method qua CLI. Đọc kỹ output
để xác định các trường: `token`, `token_policies`, `token_duration`.

**Bước 5 — Kiểm tra chi tiết token**

Dùng `vault token lookup` để xem đầy đủ thông tin của token hiện tại. Chú ý các
trường `policies`, `ttl`, và `accessor`.

**Bước 6 — Tra cứu token qua accessor**

Lấy giá trị `accessor` từ output bước 5, rồi dùng root token để tra cứu thông
tin token qua accessor đó (không cần biết giá trị token thực). Quan sát trường
`id` có giá trị gì.

### Phần 2 — Xác thực qua HTTP API

**Bước 7 — Gọi login API và quan sát JSON response**

Đặt lại `VAULT_TOKEN=root`. Dùng `curl` để gọi login endpoint của userpass, xem
toàn bộ JSON response mà không parse. Xác định:

- Trường nào chứa token cần dùng?
- Giá trị `lease_id` ở root level là gì?
- `lease_duration` của token là bao nhiêu giây?

**Bước 8 — Parse token và lưu vào biến môi trường**

Dùng `curl` kết hợp `jq` để lấy `auth.client_token` từ response, rồi lưu vào
biến `VAULT_TOKEN`. Kiểm tra `echo $VAULT_TOKEN` phải in ra giá trị bắt đầu
bằng `hvs.`.

**Bước 9 — Dùng token gọi API lookup-self**

Dùng `curl` với header `X-Vault-Token` để gọi endpoint
`GET /v1/auth/token/lookup-self`. Xác nhận response trả HTTP 200 và có thông tin
policies của alice.

**Bước 10 — Gọi API không có token, quan sát kết quả**

Gọi thử `GET /v1/auth/token/lookup-self` mà không truyền header `X-Vault-Token`.
Quan sát HTTP status code và body response.

**Bước 11 — Dùng Authorization: Bearer thay vì X-Vault-Token**

Dùng `curl` gọi lại `GET /v1/auth/token/lookup-self` với header
`Authorization: Bearer <token>` thay vì `X-Vault-Token`. Xác nhận kết quả
tương đương.

**Bước 12 — Disable userpass auth method**

Lấy lại root token, sau đó tắt userpass auth method. Xác nhận nó không còn
trong danh sách auth methods nữa.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`.

## Tiêu chí thành công

Chạy bộ kiểm tra **trước khi thực hiện bước 12** (khi userpass còn đang bật):

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
