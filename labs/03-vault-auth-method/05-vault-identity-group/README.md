---
title: Thực hành Vault Identity Groups: Internal và External
estMinutes: 20
---

# Thực hành Vault Identity Groups: Internal và External

## Mục tiêu

Sau khi hoàn thành bài thực hành này, bạn sẽ biết cách tạo Internal Group để quản lý quyền cho nhiều entities cùng lúc, và tạo External Group với Group Alias để ánh xạ quyền từ auth method bên ngoài.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết về Vault Identity Groups.
- Công cụ `jq` đã có sẵn trong Codespace.

## Nhiệm vụ của bạn

### Bước 1 — Tạo policies

Tạo hai policies với tên `dev` và `ops`. Policy `dev` cho phép đọc secret tại path `secret/data/dev`, policy `ops` cho phép đọc secret tại path `secret/data/ops`.

### Bước 2 — Enable userpass auth và tạo users

Enable auth method userpass tại path mặc định (`userpass`). Sau đó tạo hai users:
- User `alice` với password `training`
- User `bob` với password `training`

Không cần gán policy trực tiếp cho user — quyền sẽ đến từ group.

### Bước 3 — Tạo entities và aliases

Tạo hai entities:
- Entity `alice-entity`
- Entity `bob-entity`

Sau đó tạo alias cho mỗi entity liên kết với userpass auth mount:
- Alias `alice` (name khớp với username trong userpass) gắn vào `alice-entity`
- Alias `bob` (name khớp với username trong userpass) gắn vào `bob-entity`

Bạn cần lấy `mount_accessor` của userpass trước khi tạo alias.

### Bước 4 — Tạo Internal Group

Tạo Internal Group tên `dev-team` với:
- Policy `dev`
- Cả `alice-entity` và `bob-entity` là member (dùng `member_entity_ids`)

### Bước 5 — Kiểm tra kế thừa policy từ Internal Group

Đăng nhập vào Vault bằng user `alice`. Dùng lệnh `vault token capabilities` để kiểm tra rằng token của alice có thể đọc secret tại `secret/data/dev` (nhờ kế thừa policy `dev` từ group `dev-team`).

### Bước 6 — Tạo External Group

Tạo External Group tên `ops-team` với:
- `type="external"`
- Policy `ops`

Lưu lại ID của external group này — bạn sẽ cần nó ở bước tiếp theo.

### Bước 7 — Lấy accessor của userpass

Dùng lệnh `vault auth list` để lấy `accessor` của auth mount `userpass/`. Lưu lại giá trị này.

### Bước 8 — Tạo Group Alias cho External Group

Tạo group alias liên kết External Group `ops-team` với userpass mount. Giá trị `name` của alias là `alice` (để khi alice đăng nhập qua userpass, Vault nhận diện cô ấy thuộc external group này).

Bạn sẽ cần `mount_accessor` từ bước 7 và `canonical_id` (ID của external group `ops-team`) từ bước 6.

### Bước 9 — Kiểm tra kế thừa policy từ External Group

Đăng nhập lại bằng user `alice`. Dùng `vault token capabilities` để kiểm tra token của alice có thể đọc secret tại `secret/data/ops` (nhờ external group `ops-team`).

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
