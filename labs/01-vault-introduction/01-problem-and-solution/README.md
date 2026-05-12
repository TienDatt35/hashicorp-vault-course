---
title: Khám phá Vault dev server và token cơ bản
estMinutes: 15
---

# Khám phá Vault dev server và token cơ bản

## Mục tiêu

Bạn sẽ làm quen với các thao tác căn bản nhất khi sử dụng Vault: kiểm tra
trạng thái server, xác thực bằng token, khám phá secrets engine và auth method
đang hoạt động, ghi secret đầu tiên, và xem thông tin token hiện tại.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/`.

## Nhiệm vụ của bạn

### Bước 1 — Kiểm tra Vault dev server

Xác nhận Vault đang chạy và sẵn sàng nhận lệnh:

```
vault status
```

Bạn phải thấy `Sealed: false` và `Storage Type: inmem` (chế độ dev).

### Bước 2 — Xác thực bằng root token

Đăng nhập vào Vault bằng root token:

```
vault login root
```

Xác nhận output hiển thị `token: root` và `policies: [root]`.

### Bước 3 — Xem danh sách secrets engine đang bật

Liệt kê tất cả secrets engine hiện đang được kích hoạt:

```
vault secrets list
```

Ghi nhận những engine mặc định nào đã có sẵn trong chế độ dev.

### Bước 4 — Xem danh sách auth method đang bật

Liệt kê tất cả auth method hiện đang được kích hoạt:

```
vault auth list
```

Ghi nhận auth method mặc định (`token/`) luôn có mặt.

### Bước 5 — Bật KV v2 tại path `kv/`

Bật KV secrets engine phiên bản 2 ở path `kv/`. Lưu ý: **không đụng vào path
mặc định `secret/`** — hãy dùng path riêng `kv/` để tránh xung đột.

Sau khi bật, chạy lại `vault secrets list` để xác nhận `kv/` xuất hiện trong
danh sách.

### Bước 6 — Ghi secret đầu tiên

Ghi secret với username và password vào path `kv/app/db`:

- `username` = `admin`
- `password` = `s3cret-v1`

Đọc lại secret vừa ghi để xác nhận dữ liệu đã lưu thành công.

> Gợi ý: nếu bí ở bất kỳ bước nào, hãy mở `solution.md` để đối chiếu.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
