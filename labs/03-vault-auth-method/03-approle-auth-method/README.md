---
title: Thực hành AppRole Auth Method
estMinutes: 25
---

# Thực hành AppRole Auth Method

## Mục tiêu

Bật AppRole auth method, tạo role với giới hạn SecretID, thực hiện login qua
CLI và API, và kiểm chứng rằng SecretID hết hiệu lực sau khi đủ số lần dùng.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết về AppRole Auth Method.
- `curl` và `jq` có sẵn trong Codespace.

## Nhiệm vụ của bạn

### Bước 1 — Bật AppRole auth method

Bật AppRole auth method trên đường dẫn mặc định.

### Bước 2 — Tạo role `my-app`

Tạo một role tên `my-app` với các tham số sau:

- `token_policies` = `default`
- `token_ttl` = `1h`
- `secret_id_num_uses` = `5`
- `secret_id_ttl` = `30m`

### Bước 3 — Đọc RoleID

Đọc RoleID của role `my-app` và lưu vào biến `ROLE_ID` trong shell của bạn.

Gợi ý: dùng lệnh `vault read` với đường dẫn phù hợp.

### Bước 4 — Sinh SecretID (Pull mode)

Sinh một SecretID mới cho role `my-app` và lưu vào biến `SECRET_ID`.

Lưu ý: bạn cần một cờ đặc biệt khi sinh SecretID vì endpoint này không nhận
body dữ liệu. Xem lại lý thuyết nếu quên.

### Bước 5 — Login bằng AppRole qua CLI

Dùng `ROLE_ID` và `SECRET_ID` vừa có để login với AppRole qua CLI. Kiểm tra
rằng Vault trả về một token hợp lệ.

### Bước 6 — Login bằng AppRole qua API

Sinh một SecretID mới (SecretID từ bước 4 đã dùng một lần rồi), sau đó thực
hiện login bằng `curl`. Dùng `jq` để trích xuất `auth.client_token` từ kết
quả JSON và lưu vào biến `API_TOKEN`.

### Bước 7 — Dùng token để tra cứu thông tin

Dùng `API_TOKEN` vừa lấy được để gọi `vault token lookup` (hoặc API tương
đương), xác nhận token hợp lệ và mang đúng policy `default`.

### Bước 8 — Kiểm chứng giới hạn số lần dùng SecretID

Sinh một SecretID mới. Login bằng SecretID đó thêm 4 lần nữa (lần đầu là lần
thứ 1 trong tổng giới hạn 5). Lần login thứ 6 phải thất bại với lỗi từ Vault.

Xác nhận rằng Vault từ chối login khi SecretID đã hết `secret_id_num_uses`.

### Bước 9 — Sinh SecretID mới và login lại

Sinh một SecretID mới, đây là lần bắt đầu đếm lại. Login bằng SecretID mới
để xác nhận ứng dụng có thể phục hồi sau khi SecretID hết hiệu lực.

> Gợi ý: hãy tự suy nghĩ từng bước trước khi mở `solution.md`. Nếu bí, đối
> chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
