---
title: Thực hành so sánh Static và Platform Auth: AppRole vs Userpass
estMinutes: 20
---

# Thực hành so sánh Static và Platform Auth: AppRole vs Userpass

## Mục tiêu

Trong bài này, bạn sẽ trực tiếp enable và cấu hình hai loại auth method khác nhau — AppRole (static machine auth) và Userpass (static human auth) — rồi so sánh token metadata của chúng để thấy rõ sự khác biệt trong thực tế.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết về chọn auth method phù hợp trong `site/docs/03-vault-auth-method/05-diff-and-choice-auth-methods/theory.mdx`.

## Nhiệm vụ của bạn

### Bước 1 — Tạo policy dùng chung

Tạo một policy tên `dev-policy` cho phép đọc secret tại path `secret/data/dev/*`. Policy này sẽ được gắn cho cả user và AppRole role để bạn dễ so sánh.

### Bước 2 — Enable và cấu hình AppRole auth

AppRole là auth method cho machine/workload không có trusted platform. Thực hiện:

1. Enable AppRole auth method tại path mặc định `approle`.
2. Tạo AppRole role tên `dev-role` và gắn policy `dev-policy` vào role đó. Đặt `secret_id_ttl` là `24h` và `token_ttl` là `1h`.
3. Lấy `role-id` của role `dev-role`.
4. Tạo một `secret-id` mới cho role `dev-role`.
5. Dùng `role-id` và `secret-id` vừa lấy để đăng nhập vào Vault.
6. Quan sát thông tin token trả về: `auth.metadata`, `auth.policies`, `auth.token_type`.

### Bước 3 — Enable và cấu hình Userpass auth

Userpass là auth method cho người dùng, credential được quản lý bên trong Vault. Thực hiện:

1. Enable Userpass auth method tại path mặc định `userpass`.
2. Tạo user tên `alice` với password `training` và gắn policy `dev-policy`.
3. Đăng nhập vào Vault bằng user `alice`.
4. Quan sát thông tin token trả về và so sánh với token từ AppRole ở Bước 2.

### Bước 4 — Liệt kê và kiểm tra tất cả auth methods

1. Dùng lệnh `vault auth list` để xem tất cả auth methods đang được enable.
2. Quan sát accessor của từng auth method — accessor là identifier dùng để tạo entity alias và group alias.

### Bước 5 — Kiểm tra token capabilities

Dùng token vừa nhận được từ AppRole hoặc Userpass để kiểm tra xem token có quyền đọc `secret/data/dev` không. So sánh kết quả với policy `dev-policy` bạn đã tạo.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
