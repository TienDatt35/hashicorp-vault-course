---
title: Đáp án mẫu — Trải nghiệm centralized secrets & encryption as a service
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này đi qua ba nhóm thao tác:

1. **KV v2** — bật engine, ghi secret, ghi đè để tạo version mới, đọc lại version cũ. Versioning là tính năng quan trọng của KV v2: Vault tự động giữ lại các phiên bản cũ, cho phép rollback hoặc kiểm tra lịch sử thay đổi.

2. **Transit** — bật engine, tạo key, mã hóa plaintext (phải base64 trước), giải mã ciphertext (Vault trả về base64, phải decode lại). Ciphertext có prefix `vault:v1:` cho biết version của key đã dùng.

3. **Audit device** — bật file audit, thực hiện một thao tác, xem log. Vault ghi mọi request/response vào audit device.

## Các lệnh

```bash
# Bước 1 — Kiểm tra Vault đang chạy
vault status

# Bước 2 — Bật KV v2 tại path kv/
vault secrets enable -version=2 kv

# Bước 3 — Ghi secret lần đầu (version 1)
vault kv put kv/app/db username=admin password=s3cret-v1

# Bước 4a — Ghi đè để tạo version 2
vault kv put kv/app/db username=admin password=s3cret-v2

# Bước 4b — Đọc lại version 1 để xác nhận versioning
vault kv get -version=1 kv/app/db
# Bạn sẽ thấy password=s3cret-v1 ở version 1

# Đọc version mới nhất (version 2)
vault kv get kv/app/db
# Bạn sẽ thấy password=s3cret-v2

# Bước 5 — Bật Transit secrets engine
vault secrets enable transit

# Bước 6 — Tạo key aes256-gcm96 tên my-key
vault write -f transit/keys/my-key type=aes256-gcm96

# Bước 7 — Mã hóa chuỗi "hello vault"
# Plaintext phải được encode base64 trước khi gửi lên Vault
PLAINTEXT_B64=$(echo -n "hello vault" | base64)
vault write transit/encrypt/my-key plaintext="$PLAINTEXT_B64"
# Ghi lại ciphertext trả về, ví dụ: vault:v1:AbCdEf...

# Bước 8 — Giải mã (thay YOUR_CIPHERTEXT bằng ciphertext thực tế)
CIPHERTEXT="vault:v1:..."   # dán ciphertext của bạn vào đây
vault write transit/decrypt/my-key ciphertext="$CIPHERTEXT"
# Vault trả về plaintext dạng base64 — decode để đọc:
echo "BASE64_FROM_VAULT" | base64 -d
# Kết quả phải là: hello vault

# Bước 9a — Bật audit device file
vault audit enable file file_path=/tmp/vault_audit.log

# Bước 9b — Chạy một lệnh bất kỳ để tạo audit entry
vault kv get kv/app/db

# Bước 9c — Quan sát audit log
tail -n 5 /tmp/vault_audit.log | jq
# Bạn sẽ thấy JSON entry ghi lại request vault kv get vừa rồi
```

## Kiểm tra lại

```sh
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
