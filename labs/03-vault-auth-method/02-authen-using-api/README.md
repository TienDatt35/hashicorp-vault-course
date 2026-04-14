---
title: Xác thực vào Vault bằng API
estMinutes: 15
---

# Xác thực vào Vault bằng API

## Mục tiêu

Thực hành gọi Vault HTTP API để xác thực, lấy token từ JSON response, và dùng token đó cho các request tiếp theo — toàn bộ bằng `curl` và `jq`, không dùng Vault CLI để authenticate.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- `curl` và `jq` đã có sẵn trong Codespace.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/03-vault-auth-method/02-authen-using-api/theory.mdx`.

## Nhiệm vụ của bạn

### Bước 1 — Enable userpass auth method và tạo user

Dùng Vault CLI với quyền root để bật userpass auth method và tạo một user tên `alice` với password `vault123`.

Gợi ý: bạn cần hai lệnh `vault` — một để enable auth method, một để tạo user.

### Bước 2 — Gọi login API và quan sát JSON response

Dùng `curl` để gọi login endpoint của userpass, xem toàn bộ JSON response trả về mà không parse. Hãy tìm trong response và xác định:

- Trường nào chứa token thực sự bạn cần dùng?
- Giá trị `lease_id` ở root level là gì?
- `lease_duration` của token là bao nhiêu giây?

### Bước 3 — Parse và lưu token vào biến môi trường

Dùng `curl` kết hợp `jq` để lấy chính xác `auth.client_token` từ response, rồi lưu vào biến môi trường `VAULT_TOKEN`.

Sau bước này, lệnh `echo $VAULT_TOKEN` phải in ra một giá trị bắt đầu bằng `hvs.`.

### Bước 4 — Dùng token để gọi API lookup-self

Dùng `curl` với header `X-Vault-Token` để gọi endpoint `GET /v1/auth/token/lookup-self`. Endpoint này trả về thông tin của chính token bạn đang dùng.

Xác nhận response trả về HTTP 200 và có thông tin policies của token alice.

### Bước 5 — Tạo KV secret bằng API (dùng root token)

Tạm thời đặt lại `VAULT_TOKEN=root`, rồi dùng `curl` để tạo một KV secret tại đường dẫn `secret/data/hello` với nội dung `{"message": "xin chao"}`.

Gợi ý: KV v2 dùng POST với body `{"data": {"key": "value"}}`.

### Bước 6 — Đọc secret bằng token của alice qua API

Đặt lại `VAULT_TOKEN` về token của alice. Dùng `curl` với header `X-Vault-Token` để gọi `GET /v1/secret/data/hello`.

Lưu ý: alice dùng policy `default`. Quan sát xem alice có quyền đọc secret này không.

### Bước 7 — Gọi API không có token, quan sát response

Dùng `curl` gọi `GET /v1/secret/data/hello` **mà không truyền header X-Vault-Token**. Quan sát HTTP status code và body response.

### Bước 8 — Dùng Authorization: Bearer thay X-Vault-Token

Dùng `curl` gọi lại `GET /v1/auth/token/lookup-self` với header `Authorization: Bearer <token_cua_alice>` thay vì `X-Vault-Token`. Xác nhận kết quả tương đương.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
