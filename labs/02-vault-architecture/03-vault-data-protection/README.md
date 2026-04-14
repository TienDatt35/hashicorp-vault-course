---
title: "Bảo Vệ Dữ Liệu trong Vault: Encryption và Unseal"
estMinutes: 20
---

# Bảo Vệ Dữ Liệu trong Vault: Encryption và Unseal

## Mục tiêu

Trong bài này, bạn sẽ quan sát trực tiếp cơ chế bảo vệ dữ liệu của Vault: đọc trạng thái seal, xem thông tin encryption key hiện tại, thực hiện key rotation và xác nhận term tăng lên, rồi khám phá cấu hình auto-rotate.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Lưu ý: Vault dev mode tự động unsealed và không thể demo manual unseal. Bài
  này tập trung vào đọc thông tin trạng thái và thực hành key rotation.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/02-vault-architecture/03-vault-data-protection/`.

## Nhiệm vụ của bạn

### Bước 1: Kiểm tra trạng thái Vault và thông tin seal

Đặt biến môi trường và kiểm tra trạng thái tổng quan của Vault:

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'
```

Chạy lệnh kiểm tra trạng thái và đọc kỹ output. Tìm hiểu ý nghĩa của các trường sau trong output:
- `Sealed` — Vault đang ở trạng thái nào?
- `Total Shares` — Tổng số unseal key shares được tạo ra
- `Threshold` — Cần bao nhiêu shares để unseal
- `Version` — Phiên bản Vault đang chạy
- `Storage Type` — Backend lưu trữ đang dùng (dev mode dùng `inmem`)

Trong dev mode, các trường `Total Shares` và `Threshold` sẽ có giá trị đặc biệt — hãy giải thích tại sao.

### Bước 2: Xem thông tin encryption key hiện tại

Đọc thông tin về encryption key (data key) đang được dùng:

Tìm hiểu ý nghĩa của các trường trong output:
- `term` — Số thứ tự của encryption key hiện tại (tăng sau mỗi lần rotate)
- `install_time` — Thời điểm key này được tạo

Ghi lại giá trị `term` hiện tại để so sánh sau bước 3.

### Bước 3: Rotate encryption key

Thực hiện key rotation và xác nhận term đã tăng:

Sau khi rotate, đọc lại thông tin key status và so sánh:
- Term đã tăng lên bao nhiêu?
- Tại sao data cũ vẫn đọc được sau khi rotate?

Thử ghi một secret và đọc lại để xác nhận Vault hoạt động bình thường sau rotation:

```bash
vault kv put secret/test-after-rotate message="kiem tra sau khi rotate"
vault kv get secret/test-after-rotate
```

### Bước 4: Xem và cập nhật cấu hình auto-rotate

Xem cấu hình auto-rotate hiện tại của Vault:

Tìm hiểu ý nghĩa của các trường:
- `interval` — Khoảng thời gian tự động rotate (0 nghĩa là không tự động)
- `max_operations` — Số lần mã hóa tối đa trước khi buộc rotate

Thử đặt cấu hình auto-rotate với interval cụ thể và số lần mã hóa tối đa:

```bash
vault write sys/rotate/config interval=2160h max_operations=3456789
```

Sau đó đọc lại cấu hình để xác nhận thay đổi đã được áp dụng.

> Gợi ý: hãy tự suy nghĩ và thử các lệnh trước khi mở `solution.md`. Nếu bí,
> đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
