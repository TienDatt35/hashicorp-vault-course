---
title: Thực hành Transit Secrets Engine
estMinutes: 30
---

# Thực hành Transit Secrets Engine

## Mục tiêu

Hoàn thành bài này, bạn sẽ biết cách bật và sử dụng Transit Secrets Engine để mã hóa/giải mã dữ liệu, quản lý vòng đời key thông qua rotate và `min_decryption_version`, và thực hiện rewrap ciphertext mà không lộ plaintext.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR` và `VAULT_TOKEN` đã được đặt sẵn.
- Bạn đã đọc bài lý thuyết về Transit Secrets Engine.

## Nhiệm vụ của bạn

### Bước 1 — Bật Transit Secrets Engine

Bật Transit Secrets Engine tại path mặc định (`transit/`). Sau khi bật, xác nhận engine đã xuất hiện trong danh sách secrets engines.

### Bước 2 — Tạo key mặc định

Tạo một named key tên là `lab-key` với type mặc định (`aes256-gcm96`). Đọc thông tin key vừa tạo để xem `latest_version` và `min_decryption_version` ban đầu.

### Bước 3 — Encrypt dữ liệu

Mã hóa chuỗi `"Hello Vault Transit"` bằng key `lab-key`. Nhớ rằng plaintext phải được base64-encode trước khi gửi lên Vault. Lưu lại chuỗi ciphertext nhận được (bao gồm cả prefix `vault:v1:...`).

### Bước 4 — Decrypt và kiểm tra kết quả

Giải mã ciphertext vừa tạo bằng key `lab-key`. Vault trả về plaintext dưới dạng base64 — bạn cần decode để lấy lại chuỗi gốc. Xác nhận kết quả là `Hello Vault Transit`.

### Bước 5 — Rotate key và encrypt lại

Rotate key `lab-key`. Sau khi rotate, xem thông tin key và xác nhận `latest_version` đã tăng lên `2`. Tiếp theo, encrypt cùng chuỗi `"Hello Vault Transit"` một lần nữa — quan sát prefix của ciphertext mới để xác nhận đang dùng version 2.

### Bước 6 — Cấu hình min_decryption_version và kiểm tra

Đặt `min_decryption_version=2` cho key `lab-key`. Sau đó thử decrypt ciphertext `vault:v1:...` (từ bước 3) — yêu cầu này phải thất bại. Xác nhận rằng ciphertext `vault:v2:...` (từ bước 5) vẫn decrypt thành công.

### Bước 7 — Rewrap ciphertext

Sử dụng thao tác `rewrap` của Transit để chuyển ciphertext `vault:v1:...` (từ bước 3) sang key version mới nhất. Quan sát ciphertext kết quả — prefix phải là `vault:v2:...` (hoặc version mới nhất). Lưu ý: rewrap không để lộ plaintext ra ngoài.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần
> giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
