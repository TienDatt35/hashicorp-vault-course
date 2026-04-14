---
title: Đáp án mẫu — Transit Auto Unseal với Vault Dev Server
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài lab này dùng Vault A (dev server sẵn có tại port 8200) làm cluster trung tâm với Transit Secrets Engine. Vault B chạy ở chế độ production mode với `seal "transit"` trong file config HCL. Khi Vault B khởi tạo lần đầu (`vault operator init`), nó gọi Vault A để encrypt root key rồi lưu vào storage. Mỗi lần restart, Vault B gọi Vault A decrypt để lấy lại root key — đây là quá trình Auto Unseal.

Điểm then chốt: token dùng để xác thực với Vault A phải là orphan token với policy tối thiểu. Token này được đặt vào biến môi trường `VAULT_TOKEN` của process Vault B — không hardcode trong file config.

## Các lệnh

### Phần 1 — Chuẩn bị Vault A

```bash
# Đảm bảo đang làm việc với Vault A
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

# Bước 1 — Kiểm tra Vault A sẵn sàng
vault status

# Bước 2 — Enable Transit Secrets Engine
vault secrets enable transit

# Bước 3 — Tạo encryption key cho Vault B
vault write -f transit/keys/autounseal-vault-b

# Bước 4 — Tạo policy tối thiểu
vault policy write autounseal-vault-b - <<EOF
path "transit/encrypt/autounseal-vault-b" {
  capabilities = ["update"]
}
path "transit/decrypt/autounseal-vault-b" {
  capabilities = ["update"]
}
EOF

# Bước 5 — Tạo orphan periodic token và lưu vào biến
UNSEAL_TOKEN=$(vault token create \
  -orphan \
  -policy="autounseal-vault-b" \
  -period=24h \
  -field=token)

echo "Token cho Vault B: $UNSEAL_TOKEN"
```

### Phần 2 — Cấu hình và khởi động Vault B

```bash
# Bước 6 — Tạo thư mục và file config
mkdir -p /tmp/vault-b/data

cat > /tmp/vault-b/config.hcl <<EOF
seal "transit" {
  address    = "http://127.0.0.1:8200"
  key_name   = "autounseal-vault-b"
  mount_path = "transit/"
  disable_renewal = "false"
  tls_skip_verify = "true"
}

storage "file" {
  path = "/tmp/vault-b/data"
}

listener "tcp" {
  address     = "127.0.0.1:8300"
  tls_disable = "true"
}

api_addr     = "http://127.0.0.1:8300"
disable_mlock = true
EOF

# Bước 7 — Khởi động Vault B với VAULT_TOKEN trỏ về token của Vault A
VAULT_TOKEN=$UNSEAL_TOKEN vault server -config=/tmp/vault-b/config.hcl > /tmp/vault-b/vault-b.log 2>&1 &
VAULT_B_PID=$!
echo "Vault B PID: $VAULT_B_PID"

# Chờ Vault B khởi động
sleep 2
```

### Phần 3 — Khởi tạo và kiểm tra Vault B

```bash
# Bước 8 — Chuyển sang làm việc với Vault B
export VAULT_ADDR=http://127.0.0.1:8300
export VAULT_TOKEN=""

# Kiểm tra Vault B đang chạy (sẽ thấy Initialized: false, Sealed: true)
vault status

# Bước 9 — Khởi tạo Vault B
vault operator init -key-shares=5 -key-threshold=3 -format=json > /tmp/vault-b/init.json
cat /tmp/vault-b/init.json

# Bước 10 — Kiểm tra trạng thái sau init
vault status
```

## Giải thích output vault status

Sau khi init thành công, `vault status` tại port 8300 sẽ hiển thị tương tự:

```
Key                      Value
---                      -----
Recovery Seal Type       shamir
Initialized              true
Sealed                   false
Total Recovery Shares    5
Threshold                3
Version                  1.x.x
```

Điểm quan trọng:
- `Sealed: false` — Vault B đã tự động unseal ngay sau init mà không cần nhập bất kỳ key nào.
- `Recovery Seal Type: shamir` — thay vì `Seal Type: shamir`, trường này xác nhận Vault B đang dùng Auto Unseal.
- File `/tmp/vault-b/init.json` chứa `recovery_keys` (không phải `unseal_keys`).

## Ghi chú về tls_skip_verify

Trong lab này dùng `tls_skip_verify = "true"` vì kết nối nội bộ localhost không có TLS thực. Trong môi trường production, **không bao giờ** đặt `tls_skip_verify = "true"` — phải cấu hình `tls_ca_cert` và `tls_server_name` đúng.

## Kiểm tra lại

Khôi phục biến môi trường về Vault A rồi chạy verify:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
