---
title: Vault Initialization
estMinutes: 20
---

# Vault Initialization

## Mục tiêu

Trong bài này bạn sẽ khởi động một Vault server ở production mode (không phải dev mode), thực hiện init thực sự với tùy chọn tùy chỉnh, lưu unseal keys, và unseal Vault để nó sẵn sàng phục vụ. Đây là toàn bộ quy trình bạn sẽ thực hiện trong môi trường thực tế.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này. Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bài này cần một Vault **production mode** chạy riêng ở port **8300** — bạn sẽ khởi động nó trong các bước dưới đây.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/02-vault-architecture/08-vault-init/`.

## Nhiệm vụ của bạn

### Bước 1 — Quan sát Vault dev server đã được init sẵn

Kiểm tra trạng thái Vault dev server tại port 8200. Xác nhận trường `Initialized` có giá trị `true` và `Sealed` có giá trị `false`. Đây là kết quả dev mode tự động init và unseal.

### Bước 2 — Tạo config file cho Vault production mode

Tạo thư mục làm việc tại `/tmp/vault-init-lab/`. Bên trong, tạo file `config.hcl` với cấu hình tối thiểu cho Vault production: sử dụng `file` storage backend lưu tại `/tmp/vault-init-lab/data`, listener trên `127.0.0.1:8300` (tắt TLS bằng `tls_disable = "true"`), và đặt `api_addr = "http://127.0.0.1:8300"`.

### Bước 3 — Khởi động Vault production server

Khởi động Vault production server chạy nền (background) với file config vừa tạo. Chờ một giây để server khởi động hoàn tất.

### Bước 4 — Xác nhận Vault chưa được init

Trỏ VAULT_ADDR tới port 8300 và kiểm tra trạng thái. Xác nhận `Initialized = false`. Thử chạy `vault operator init -status` và quan sát exit code trả về (phải là 2, không phải 0).

### Bước 5 — Thực hiện init với tùy chỉnh

Init Vault với **3 key shares** và **threshold là 2**. Lưu toàn bộ output vào một file để tham chiếu. Xác định 3 unseal keys và initial root token từ output.

### Bước 6 — Kiểm tra trạng thái sau init

Chạy `vault status`. Xác nhận `Initialized = true` và `Sealed = true` — Vault đã được init nhưng chưa unseal.

### Bước 7 — Unseal Vault bằng 2 trong 3 keys

Vault cần ít nhất 2 keys (theo threshold bạn đặt). Chạy `vault operator unseal` hai lần với hai unseal keys khác nhau. Sau lần thứ hai, `vault status` phải cho thấy `Sealed = false`.

### Bước 8 — Đăng nhập và xác minh

Đăng nhập bằng initial root token bằng lệnh `vault login`. Sau đó chạy `vault status` một lần nữa để xác nhận Vault hoàn toàn hoạt động.

> Gợi ý: hãy tự suy nghĩ về từng bước trước khi mở `solution.md`. Đặc biệt chú ý đến cách export biến môi trường VAULT_ADDR khi làm việc với server trên port 8300 song song với dev server ở port 8200.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
