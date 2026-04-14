---
title: Giới thiệu Auth Methods
estMinutes: 15
---

# Giới thiệu Auth Methods

## Mục tiêu

Sau khi hoàn thành bài thực hành, bạn sẽ biết cách enable và quản lý auth
method trong Vault, tạo user xác thực, login để lấy token, kiểm tra thông tin
token qua accessor, và disable auth method khi không còn cần.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR` và `VAULT_TOKEN` đã được thiết lập sẵn.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/03-vault-auth-method/01-auth-method-introduction/`.

## Nhiệm vụ của bạn

**Bước 1 — Xem các auth methods mặc định**

Liệt kê tất cả auth methods đang bật trong Vault. Quan sát xem auth method nào
đã có sẵn mà không cần bạn bật thêm.

**Bước 2 — Enable userpass auth method**

Bật userpass auth method. Đây là auth method dùng tên người dùng và mật khẩu.
Sau khi bật, kiểm tra lại danh sách auth methods để xác nhận.

**Bước 3 — Tạo người dùng**

Tạo một user có tên `alice` trong userpass auth method. User này cần có mật
khẩu và được gắn policy `default`.

**Bước 4 — Login bằng userpass và quan sát kết quả**

Đăng nhập với tài khoản `alice` bằng userpass auth method. Đọc kỹ output để
tìm các trường: `token`, `token_policies`, `token_duration`.

**Bước 5 — Kiểm tra chi tiết token vừa nhận**

Dùng lệnh `vault token lookup` để xem đầy đủ thông tin của token bạn vừa
nhận được. Chú ý đến các trường `policies`, `ttl`, và `accessor`.

**Bước 6 — Tra cứu token qua accessor**

Lấy giá trị `accessor` từ output bước 5, rồi dùng accessor đó để tra cứu
token mà không cần dùng đến giá trị token thực. Quan sát sự khác biệt so với
bước 5.

**Bước 7 — Thử gọi Vault không có token**

Gọi thử một Vault API endpoint mà không kèm token. Quan sát Vault phản hồi
như thế nào.

**Bước 8 — Disable userpass auth method**

Tắt userpass auth method. Sau khi tắt, hãy xác nhận nó không còn trong danh
sách auth methods nữa.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với
> phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

Lưu ý: `verify.sh` kiểm tra trạng thái **sau khi bạn hoàn thành bước 1-5**
(trước khi disable). Hãy chạy `verify.sh` trước khi thực hiện bước 8.

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
