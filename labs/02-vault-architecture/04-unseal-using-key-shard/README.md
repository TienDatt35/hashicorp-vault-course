---
title: Unseal Vault bằng Key Shards
estMinutes: 20
---

# Unseal Vault bằng Key Shards

## Mục tiêu

Thực hành toàn bộ quy trình khởi tạo và unseal Vault thực tế: tạo config file, chạy Vault ở production mode, khởi tạo với Shamir Secret Sharing, và unseal từng bước để quan sát progress thay đổi.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này. Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng về kiến trúc 3 lớp mã hóa và Shamir Secret Sharing.

> **Lưu ý quan trọng**: Vault dev server tự động init và tự unseal — bạn không thể học được quy trình unseal thực sự với dev server. Bài lab này yêu cầu bạn dừng dev server và khởi động Vault ở **production mode** với storage thực để thực hành init và unseal từ đầu.

## Nhiệm vụ của bạn

### Bước 1: Kiểm tra Vault dev server đang chạy

Xác nhận dev server đang hoạt động bằng cách kiểm tra trạng thái hiện tại. Chú ý các trường `Seal Type`, `Initialized`, `Sealed` trong output.

### Bước 2: Dừng Vault dev server

Tìm và dừng tiến trình Vault dev server đang chạy để chuẩn bị khởi động Vault production mode.

### Bước 3: Tạo config file cho Vault production mode

Tạo thư mục làm việc tại `/tmp/vault-lab/` gồm:
- Thư mục `data/` để Vault lưu trữ dữ liệu (file storage backend)
- File config `config.hcl` với các thiết lập:
  - Storage backend: `file`, path là `/tmp/vault-lab/data`
  - Listener: `tcp`, address `127.0.0.1:8200`, `tls_disable = true`
  - `disable_mlock = true` (cần thiết trong môi trường container/Codespace)

### Bước 4: Khởi động Vault production mode

Khởi động Vault server với config file vừa tạo ở background. Đợi vài giây để server sẵn sàng, sau đó chạy `vault status` để xác nhận Vault đang ở trạng thái `Initialized = false`.

### Bước 5: Khởi tạo Vault với Shamir Secret Sharing

Chạy `vault operator init` với tham số tùy chỉnh:
- 3 key shares (để bài lab ngắn gọn hơn mặc định 5)
- Threshold là 2 (cần 2 trong 3 shares để unseal)

Lưu lại toàn bộ output — bao gồm 3 Unseal Keys và Initial Root Token. Trong thực tế, đây là bước quan trọng nhất: mất keys nghĩa là mất quyền truy cập vào Vault vĩnh viễn.

### Bước 6: Unseal Vault từng bước

Thực hiện unseal theo hai bước riêng biệt:

1. Nộp Unseal Key đầu tiên bằng `vault operator unseal`. Sau đó chạy `vault status` và quan sát `Unseal Progress` thay đổi từ `0/2` lên `1/2`.
2. Nộp Unseal Key thứ hai. Chạy `vault status` lần nữa và xác nhận `Sealed = false`.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

### Bước 7: Đăng nhập và xác nhận

Đặt biến môi trường `VAULT_TOKEN` bằng Initial Root Token vừa lưu được, sau đó chạy `vault status` lần cuối để xác nhận Vault đã hoàn toàn unsealed và sẵn sàng.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
