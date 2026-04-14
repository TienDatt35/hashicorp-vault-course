---
title: "Đáp án mẫu — Bảo Vệ Dữ Liệu trong Vault: Encryption và Unseal"
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này khám phá mô hình bảo vệ dữ liệu 3 lớp của Vault thông qua các lệnh
`sys/key-status` và `vault operator rotate`. Trong dev mode, Vault dùng storage
`inmem` (in-memory) và tự động unsealed — các trường `Total Shares` và
`Threshold` có thể hiển thị giá trị 0 hoặc 1 vì dev server không tạo unseal
key shares thực sự. Bài thực hành chứng minh rằng key rotation là thao tác
trực tuyến: term tăng, data cũ vẫn đọc được vì key cũ được giữ lại trong keyring.

## Các lệnh

```bash
# --- Thiết lập biến môi trường ---
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# --- Bước 1: Kiểm tra trạng thái Vault ---
vault status
```

Output mẫu trong dev mode:
```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.x.x
Build Date      ...
Storage Type    inmem
Cluster Name    vault-cluster-...
Cluster ID      ...
HA Enabled      false
```

Trong dev mode:
- `Sealed: false` — Vault tự động unsealed khi khởi động với flag `-dev`
- `Total Shares: 1` và `Threshold: 1` — dev mode chỉ tạo 1 share để đơn giản hóa; trong production thường là 5 shares, threshold 3
- `Storage Type: inmem` — dữ liệu lưu trong memory, mất khi Vault restart

```bash
# --- Bước 2: Xem encryption key hiện tại ---
vault read sys/key-status
```

Output mẫu:
```
Key            Value
---            -----
install_time   2024-01-15T10:00:00.000000000Z
encryptions    42
term           1
```

- `term: 1` — đây là encryption key đầu tiên, chưa bao giờ rotate
- `install_time` — thời điểm key này được tạo (khi Vault khởi động lần đầu)
- `encryptions` — số lần key này đã dùng để mã hóa

```bash
# --- Bước 3: Rotate encryption key ---
vault operator rotate
```

Output sau khi rotate:
```
Key Term        2
Install Time    2024-01-15T10:05:00.000000000Z
Encryptions     0
```

Vault xác nhận key mới (term 2) đã được tạo và thêm vào keyring.

```bash
# Xác nhận term đã tăng
vault read sys/key-status
# term bây giờ là 2

# Kiểm tra data vẫn hoạt động bình thường sau rotation
vault kv put secret/test-after-rotate message="kiem tra sau khi rotate"
vault kv get secret/test-after-rotate
```

Tại sao data cũ vẫn đọc được: Vault giữ tất cả encryption keys từ trước trong
keyring (được mã hóa bởi root key). Khi đọc một secret cũ, Vault biết nó được
mã hóa bởi key nào (dựa vào metadata), lấy đúng key từ keyring, và giải mã.
Key mới chỉ dùng cho write mới.

```bash
# --- Bước 4: Xem và cập nhật cấu hình auto-rotate ---
vault read sys/rotate/config
```

Output mẫu:
```
Key               Value
---               -----
interval          0s
max_operations    3865470566
```

- `interval: 0s` — không tự động rotate theo thời gian (0 nghĩa là tắt)
- `max_operations` — ngưỡng số lần mã hóa, sau đó Vault tự rotate; giá trị
  mặc định rất lớn vì AES-256-GCM an toàn trong rất nhiều lần dùng

```bash
# Đặt cấu hình auto-rotate: rotate sau mỗi 2160 giờ (90 ngày)
# và tối đa 3456789 lần mã hóa
vault write sys/rotate/config interval=2160h max_operations=3456789

# Xác nhận cấu hình đã áp dụng
vault read sys/rotate/config
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
