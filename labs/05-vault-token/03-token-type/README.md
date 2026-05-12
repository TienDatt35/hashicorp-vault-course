---
title: Thực hành Các loại Token
estMinutes: 25
---

# Thực hành Các loại Token

## Mục tiêu

Tạo, so sánh và kiểm chứng hành vi thực tế của service token, batch token, periodic token, orphan token, token store role, và AppRole role trên Vault dev server.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/05-vault-token/03-token-type/theory.mdx`.

## Nhiệm vụ của bạn

### Bước 1 — Tạo service token và batch token, so sánh prefix

Tạo một service token với policy `default` và TTL 30 phút.

Tạo một batch token với policy `default` và TTL 10 phút.

Quan sát prefix của mỗi token (`hvs.` và `hvb.`).

Thử renew batch token và quan sát thông báo lỗi từ Vault.

Lưu giá trị batch token vào biến môi trường `BATCH_TOKEN`.

### Bước 2 — Tạo periodic token và kiểm chứng TTL reset

Tạo một periodic token với:
- `period` là `2m` (2 phút)
- policy: `default`

Lookup token vừa tạo và quan sát: trường `expire_time` có giá trị gì? Trường `period` có giá trị gì?

Chờ khoảng 30 giây, sau đó renew token. Quan sát TTL sau khi renew — nó đã được reset về gần 2 phút chưa?

Lưu accessor của periodic token vào biến môi trường `PERIODIC_ACCESSOR`.

### Bước 3 — Kiểm chứng cascade revocation và orphan token

Tạo một **parent token** với policy `default` và TTL 10 phút. Ghi nhận giá trị token này.

Dùng parent token đó (bằng cách set `VAULT_TOKEN` tạm thời hoặc dùng flag `-token`) để tạo một **child token** với policy `default`.

Quay lại dùng root token, tạo thêm một **orphan token** với policy `default` và TTL 10 phút.

Revoke parent token bằng root token.

Kiểm tra: child token có còn hợp lệ không (lookup thất bại)? Orphan token có còn hợp lệ không (lookup thành công)?

Lưu accessor của orphan token vào biến môi trường `ORPHAN_ACCESSOR`.

### Bước 4 — Tạo token store role sinh batch token

Tạo một token store role tên `my-batch-role` với:
- `token_type` là `batch`
- `token_ttl` là `15m`
- `allowed_policies` là `default`

Tạo token từ role này bằng lệnh `vault token create -role=my-batch-role`.

Quan sát prefix của token — phải là `hvb.`.

Lưu token này vào biến môi trường `ROLE_BATCH_TOKEN`.

### Bước 5 — Cấu hình AppRole sinh periodic service token

Enable auth method AppRole (nếu chưa có).

Tạo AppRole role tên `my-daemon` với:
- `token_type` là `service`
- `token_period` là `2m`
- `token_policies` là `default`

Lấy `role_id` của role vừa tạo.

Tạo `secret_id` cho role.

Login bằng AppRole để nhận token.

Kiểm tra token nhận được: `type` phải là `service`, `period` phải là `2m`, `expire_time` phải trống.

Lưu accessor của token AppRole vào biến môi trường `APPROLE_ACCESSOR`.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Lưu các giá trị cần thiết vào biến môi trường trước khi chạy verify:

```bash
export BATCH_TOKEN=<batch token từ bước 1>
export PERIODIC_ACCESSOR=<accessor của periodic token bước 2>
export ORPHAN_ACCESSOR=<accessor của orphan token bước 3>
export ROLE_BATCH_TOKEN=<batch token từ role bước 4>
export APPROLE_ACCESSOR=<accessor của token AppRole bước 5>
```

Sau đó chạy bộ kiểm tra:

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
