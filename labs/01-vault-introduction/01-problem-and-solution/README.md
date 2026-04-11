---
title: Trải nghiệm centralized secrets & encryption as a service
estMinutes: 20
---

# Trải nghiệm centralized secrets & encryption as a service

## Mục tiêu

Bạn sẽ trực tiếp trải nghiệm hai trong năm trụ cột của Vault: **centralized secrets với KV v2** (versioning, overwrite, đọc lại phiên bản cũ) và **encryption as a service với Transit** (mã hóa, giải mã, round-trip). Kết thúc bài, bạn cũng sẽ bật audit device và tự quan sát request của mình được ghi lại.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết `theory.mdx` tương ứng trong `site/docs/`.

## Nhiệm vụ của bạn

### Bước 1 — Kiểm tra Vault dev server

Xác nhận Vault đang chạy và sẵn sàng nhận lệnh:

```
vault status
```

Bạn phải thấy `Sealed: false` và `HA Enabled: false` (chế độ dev).

### Bước 2 — Bật KV v2 tại path `kv/`

Bật KV secrets engine phiên bản 2 ở path `kv/`. Lưu ý: **không đụng vào path mặc định `secret/`** — hãy dùng path riêng `kv/` để tránh xung đột.

### Bước 3 — Ghi secret đầu tiên

Ghi secret với username và password vào path `kv/app/db`:

- `username` = `admin`
- `password` = `s3cret-v1`

### Bước 4 — Ghi đè và kiểm tra versioning

Ghi đè secret tại `kv/app/db` với password mới `s3cret-v2` (giữ nguyên username `admin`). Đây là version 2.

Sau đó, đọc lại **version 1** để xác nhận versioning hoạt động và password cũ vẫn còn được lưu.

### Bước 5 — Bật Transit secrets engine

Bật `transit` secrets engine tại path mặc định `transit/`.

### Bước 6 — Tạo encryption key

Tạo một key tên `my-key` với type `aes256-gcm96` trong transit engine.

### Bước 7 — Mã hóa dữ liệu

Mã hóa chuỗi `hello vault` bằng key `my-key`. Lưu ý: Transit engine yêu cầu plaintext được encode dưới dạng base64 trước khi gửi. Ghi lại ciphertext trả về (có dạng `vault:v1:...`).

### Bước 8 — Giải mã và xác nhận

Dùng key `my-key` để giải mã ciphertext vừa nhận. Decode kết quả từ base64 và xác nhận plaintext khớp với `hello vault`.

### Bước 9 — Bật audit device và quan sát log

Bật audit device kiểu `file` ghi ra `/tmp/vault_audit.log`. Sau đó chạy một lệnh bất kỳ (ví dụ đọc lại `kv/app/db`) rồi xem tail của file log để thấy request vừa rồi được ghi lại.

> Ghi chú: trong Vault dev mode, log không bền vững qua restart. Đây chỉ để minh họa cơ chế audit; trong production, bạn cần log lưu vào storage bền vững và backup thường xuyên.

> Gợi ý: nếu bí ở bất kỳ bước nào, hãy mở `solution.md` để đối chiếu.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
