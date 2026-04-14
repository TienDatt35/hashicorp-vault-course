---
title: Khám phá các thành phần cốt lõi của Vault
estMinutes: 20
---

# Khám phá các thành phần cốt lõi của Vault

## Mục tiêu

Sau khi hoàn thành bài thực hành này, bạn sẽ biết cách enable và tương tác với ba thành phần chính của Vault: Secrets Engine, Auth Method và Audit Device — và xác nhận chúng hoạt động đúng bằng các lệnh CLI.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết "Các Thành Phần Cốt Lõi của Vault" trong `site/docs/02-vault-architecture/01-vault-components/`.

## Nhiệm vụ của bạn

### Bước 1: Kiểm tra kết nối Vault

Trước tiên, xác nhận rằng Vault đang chạy và bạn có thể kết nối được. Thiết lập biến môi trường và kiểm tra trạng thái Vault.

Bạn cần thấy trạng thái Vault là `sealed: false` và `initialized: true`.

### Bước 2: Làm việc với Secrets Engine

Enable hai instance của KV secrets engine tại hai path khác nhau:

- Một instance tại path `secret/`
- Một instance tại path `kv-dev/`

Sau đó, liệt kê tất cả secrets engine đang chạy để xác nhận cả hai đã được enable.

Tiếp theo, ghi một secret vào path `secret/my-app` với key `password` có giá trị bất kỳ, sau đó đọc lại secret đó để xác nhận.

### Bước 3: Làm việc với Auth Methods

Enable auth method `userpass`. Sau khi enable, tạo một user tên `alice` với password tùy chọn và gán policy `default`.

Liệt kê tất cả auth method đang bật để xác nhận `userpass` đã xuất hiện.

### Bước 4: Làm việc với Audit Devices

Enable một audit device loại `file` và ghi log vào đường dẫn `/tmp/vault-audit.log`.

Liệt kê tất cả audit device đang bật để xác nhận device vừa tạo đã hoạt động.

### Bước 5: Xác nhận audit log hoạt động

Thực hiện một thao tác bất kỳ với Vault (ví dụ đọc lại secret đã tạo ở Bước 2). Sau đó kiểm tra file `/tmp/vault-audit.log` để xác nhận thao tác đó đã được ghi lại.

> Gợi ý: hãy tự suy nghĩ và thử các lệnh trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
