---
title: Thực hành wildcard và ACL Templating trong Vault Policy
estMinutes: 15
---

# Thực hành wildcard và ACL Templating trong Vault Policy

## Mục tiêu

Sau khi hoàn thành bài thực hành, bạn sẽ biết cách sử dụng wildcard `+` và prefix pattern `*` để viết policy linh hoạt, đồng thời tạo được ACL Template policy cho phép nhiều người dùng dùng chung một policy mà vẫn cách ly dữ liệu với nhau.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR` và `VAULT_TOKEN` đã được thiết lập sẵn.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/04-vault-policy/04-custom-path/`.

## Nhiệm vụ của bạn

### Bước 1: Tạo secrets để thực hành

Tạo các secrets sau trên KV v2 (mount `secret/`):

- `secret/apps/dev/webapp` với trường `api_key=dev-key`
- `secret/apps/prod/webapp` với trường `api_key=prod-key`
- `secret/apps/dev/database` với trường `host=db:5432`
- `secret/apps/dev/db-primary` với trường `host=primary:5432`
- `secret/apps/dev/db-replica` với trường `host=replica:5432`

### Bước 2: Tạo policy dùng wildcard `+`

Tạo policy tên `env-webapp` với các quyền sau:

- Cho phép `read` tại `secret/data/apps/+/webapp` (dùng `+` để match bất kỳ environment nào).
- Cho phép `list` tại `secret/metadata/apps/+/webapp`.

Tạo một token gắn policy `env-webapp`. Dùng token đó để xác nhận:
- Đọc được `secret/apps/dev/webapp`.
- Đọc được `secret/apps/prod/webapp`.
- Không đọc được `secret/apps/dev/database` (bị từ chối).

### Bước 3: Tạo policy dùng prefix pattern `db-*`

Tạo policy tên `db-prefix` với quyền `read` tại `secret/data/apps/dev/db-*`.

Tạo một token gắn policy `db-prefix`. Dùng token đó để xác nhận:
- Đọc được `secret/apps/dev/db-primary`.
- Đọc được `secret/apps/dev/db-replica`.
- Không đọc được `secret/apps/dev/database` (không có prefix `db-`).

### Bước 4: Tạo ACL Templating policy

Bước này tạo policy động dùng `{{identity.entity.id}}`:

1. Enable auth method userpass: `vault auth enable userpass`.
2. Tạo user `alice` với password `training`.
3. Tạo entity tên `alice-entity` với metadata `team=platform`.
4. Lấy mount accessor của userpass, sau đó tạo entity alias liên kết username `alice` với entity `alice-entity`.
5. Tạo policy tên `per-entity` với rule cho phép `create`, `read`, `update`, `delete`, `list` tại `secret/data/{{identity.entity.id}}/*`.
6. Gắn policy `per-entity` vào entity `alice-entity`.
7. Login bằng alice để lấy token của alice, sau đó dùng `vault token lookup` để xem `entity_id`.
8. Dùng `entity_id` vừa lấy được để tạo secret tại `secret/apps/dev/db-primary` (ví dụ: `vault kv put secret/<entity_id>/config env=dev`).
9. Xác nhận đọc lại được secret đó bằng token của alice.

### Bước 5: Xác nhận entity_id trong token

Dùng lệnh `vault token lookup` với token của alice để kiểm tra trường `entity_id` không rỗng.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
