---
title: Gán Policy và Kiểm Tra Quyền Truy Cập
estMinutes: 25
---

# Gán Policy và Kiểm Tra Quyền Truy Cập

## Mục tiêu

Sau khi hoàn thành bài này, bạn sẽ biết cách tạo token với policy cụ thể, xác minh policy gắn với token, và kiểm chứng rằng policy thực sự cấp đúng quyền — không hơn, không kém.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR` và `VAULT_TOKEN` đã được cấu hình sẵn.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/04-vault-policy/05-using-policy/theory.mdx`.

## Nhiệm vụ của bạn

### Bước 1 — Bật KV v2 và chuẩn bị dữ liệu

Vault dev server đã mount sẵn một KV v2 engine tại path `secret/`. Tạo hai secret sau để dùng cho bài kiểm tra:

- Tạo secret tại `secret/webapp/config` với ít nhất một cặp key/value.
- Tạo secret tại `secret/other-app/config` với ít nhất một cặp key/value.

### Bước 2 — Tạo webapp policy

Viết file HCL cho webapp policy với các quy tắc sau, rồi ghi policy đó vào Vault với tên `webapp`:

- Cho phép các thao tác `create`, `read`, `update`, `delete` tại `secret/data/webapp/*`.
- Cho phép thao tác `list` tại `secret/metadata/webapp/*`.

Xác nhận policy đã được ghi bằng cách đọc lại nội dung của nó.

### Bước 3 — Tạo token với webapp policy

Tạo một token mới được gắn với `webapp` policy. Lưu giá trị token vào một biến để dùng cho các bước tiếp theo.

### Bước 4 — Kiểm tra policies gắn với token

Dùng `vault token lookup` để xem danh sách policy gắn với token vừa tạo. Xác nhận rằng token có cả `default` và `webapp` trong danh sách policies.

Dùng thêm `vault token capabilities` để kiểm tra capabilities của token tại hai path:
- `secret/data/webapp/config` — phải thấy `[create delete read update]` hoặc tương đương.
- `secret/data/other-app/config` — phải thấy `[]` hoặc `deny`.

### Bước 5 — Đăng nhập và kiểm tra thực tế

Đăng nhập Vault bằng token webapp vừa tạo, sau đó:

1. Thử đọc secret tại `secret/webapp/config` — bước này phải thành công.
2. Thử đọc secret tại `secret/other-app/config` — bước này phải thất bại với lỗi permission denied.

Sau khi kiểm tra xong, quay lại root token.

### Bước 6 — Tạo operator policy

Viết file HCL cho operator policy với ít nhất các quy tắc sau, rồi ghi vào Vault với tên `operator`:

- `sys/health` — capabilities `["read", "sudo"]`
- `sys/policies/acl` — capabilities `["list"]`
- `sys/policies/acl/*` — capabilities `["create", "read", "update", "delete", "list", "sudo"]`
- `sys/auth` — capabilities `["read"]`
- `sys/auth/*` — capabilities `["create", "update", "delete", "sudo"]`
- `sys/mounts` — capabilities `["read"]`
- `sys/mounts/*` — capabilities `["create", "read", "update", "delete", "list", "sudo"]`

### Bước 7 — Tạo token với operator policy và kiểm tra

Tạo token mới được gắn với `operator` policy. Dùng `vault token lookup` xác nhận token có policy `operator` và `default`. Kiểm tra capabilities tại `sys/health` — phải thấy `[read sudo]` hoặc tương đương.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
