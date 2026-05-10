---
title: Thực hành Token Metadata
estMinutes: 20
---

# Thực hành Token Metadata

## Mục tiêu

Thực hành trực tiếp với output `vault token lookup` để nhận dạng từng nhóm trường metadata, kiểm chứng hành vi của `explicit_max_ttl`, `num_uses`, `accessor`, và `orphan` trên Vault dev server.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/05-vault-token/02-token-metadata/theory.mdx`.

## Nhiệm vụ của bạn

### Bước 1 — Đọc metadata của root token

Chạy `vault token lookup` (không có argument) để xem metadata của token hiện tại (root token).

Nhận dạng và ghi chú lại giá trị của các trường: `accessor`, `display_name`, `policies`, `orphan`, `type`.

### Bước 2 — Tạo token với display_name và metadata

Tạo một service token mới với các thuộc tính sau:
- `display_name` đặt là `lab-user`
- metadata: `env=lab`
- policy: `default`

Sau khi tạo xong, chạy `vault token lookup` trên token vừa tạo để xác nhận các trường `display_name` và `meta` có giá trị đúng như kỳ vọng.

Lưu lại giá trị `accessor` của token này vào một biến shell hoặc file tạm — bạn sẽ cần nó ở bước verify.

### Bước 3 — Kiểm chứng explicit_max_ttl

Tạo một token mới với:
- `ttl` là `2m` (2 phút)
- `explicit-max-ttl` là `5m` (5 phút)
- policy: `default`

Renew token này lần đầu — thao tác phải thành công.

Renew lần hai với yêu cầu TTL tổng vượt quá 5 phút kể từ lúc tạo — quan sát thông báo lỗi từ Vault.

Lưu lại giá trị `accessor` của token này.

### Bước 4 — Kiểm chứng num_uses

Tạo một token mới với:
- `use-limit` là `3`
- policy: `default`

Gọi `vault token lookup <TOKEN>` đúng 3 lần. Sau lần thứ 3, cố gắng gọi thêm một lần nữa và quan sát kết quả.

### Bước 5 — Kiểm chứng orphan token

Tạo một **parent token** với policy `default`.

Từ parent token đó, tạo một **child token** thông thường (không orphan).

Sau đó, tạo thêm một **orphan token** độc lập bằng cách dùng root token với flag `-orphan`.

Revoke parent token. Kiểm tra:
- Child token đã bị revoke chưa (lookup trả về lỗi)?
- Orphan token vẫn còn sống không (lookup thành công)?

Lưu lại giá trị `accessor` của orphan token.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Lưu các accessor vào biến môi trường trước khi chạy verify:

```bash
export LAB_ACCESSOR=<accessor của token bước 2>
export MAX_TTL_ACCESSOR=<accessor của token bước 3>
export ORPHAN_ACCESSOR=<accessor của orphan token bước 5>
```

Sau đó chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
