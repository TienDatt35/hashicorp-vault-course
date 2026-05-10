---
title: Thực hành Cubbyhole và Response Wrapping
estMinutes: 20
---

# Thực hành Cubbyhole và Response Wrapping

## Mục tiêu

Sau khi hoàn thành bài này, bạn sẽ biết cách ghi và đọc secret trong Cubbyhole, xác nhận isolation giữa các token, sử dụng Response Wrapping để truyền secret an toàn, và kiểm tra tính chất single-use của wrapping token.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR` và `VAULT_TOKEN` đã được đặt sẵn.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/`.

## Nhiệm vụ của bạn

### Bước 1 — Ghi và đọc secret vào Cubbyhole

Ghi một secret vào cubbyhole của token hiện tại (root token) với path `cubbyhole/lab-note` và field `content` có giá trị bất kỳ bạn muốn. Sau đó đọc lại secret vừa ghi để xác nhận thành công.

### Bước 2 — Xác nhận Cubbyhole isolation giữa hai token

Tạo một token mới với policy `default`. Dùng token mới đó để cố gắng đọc secret `cubbyhole/lab-note` mà root token đã ghi ở Bước 1. Quan sát kết quả để xác nhận isolation hoạt động đúng.

> Gợi ý: dùng biến môi trường `VAULT_TOKEN` tạm thời khi chạy lệnh với token mới, không cần logout khỏi root token.

### Bước 3 — Chuẩn bị secret trong KV và thực hiện Response Wrapping

Ghi một secret vào KV v2 (mount `secret/`) với path `lab/db-password` và field `value` chứa một chuỗi password giả. Sau đó đọc secret đó với flag `-wrap-ttl=120s` để nhận wrapping token thay vì plaintext.

Lưu wrapping token vào biến shell để dùng ở các bước tiếp theo.

### Bước 4 — Kiểm tra creation_path của wrapping token

Dùng API `/sys/wrapping/lookup` để kiểm tra thông tin wrapping token vừa nhận. Xác nhận trường `creation_path` khớp với path bạn đã đọc (`secret/data/lab/db-password`).

> Gợi ý: dùng `curl` với header `X-Vault-Token` hoặc lệnh Vault CLI tương đương.

### Bước 5 — Unwrap để lấy secret thật

Dùng lệnh `vault unwrap` với wrapping token đã lưu để lấy giá trị thật của `lab/db-password`. Xác nhận giá trị trả về khớp với password bạn đã ghi ở Bước 3.

### Bước 6 — Xác nhận single-use — thử unwrap lần hai

Dùng lại wrapping token từ Bước 3 để thử unwrap lần thứ hai. Quan sát thông báo lỗi và giải thích tại sao điều này xảy ra.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
