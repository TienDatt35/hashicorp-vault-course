---
title: Vault Initialization — Đáp án mẫu
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này minh họa sự khác biệt giữa **dev mode** (tự động init + unseal) và **production mode** (bạn phải tự init và unseal). Khi chạy `vault operator init`, Vault tạo ra bộ khóa mã hóa 3 lớp, chia root key thành các unseal key shares, và cấp initial root token. Vault ở trạng thái `Sealed = true` cho đến khi bạn nhập đủ threshold unseal keys.

Các flag `-key-shares=3 -key-threshold=2` tạo ra 3 unseal keys nhưng chỉ cần 2 để unseal — đây là ví dụ về cân bằng giữa bảo mật và tiện vận hành.

## Các lệnh

```bash
# Bước 1 — Quan sát dev server đã init sẵn
vault status
# Kết quả: Initialized = true, Sealed = false

# Bước 2 — Tạo thư mục và config file
mkdir -p /tmp/vault-init-lab/data

cat > /tmp/vault-init-lab/config.hcl << 'EOF'
storage "file" {
  path = "/tmp/vault-init-lab/data"
}

listener "tcp" {
  address     = "127.0.0.1:8300"
  tls_disable = "true"
}

api_addr = "http://127.0.0.1:8300"
EOF

# Bước 3 — Khởi động Vault production server ở nền
VAULT_ADDR=http://127.0.0.1:8300 \
  nohup vault server -config=/tmp/vault-init-lab/config.hcl \
  >/tmp/vault-init-lab/vault.log 2>&1 &

# Chờ server sẵn sàng
sleep 2

# Bước 4 — Kiểm tra chưa init
export VAULT_ADDR=http://127.0.0.1:8300
vault status
# Kết quả: Initialized = false, Sealed = true (storage chưa có gì)

vault operator init -status
echo "Exit code: $?"
# Kết quả: exit code 2 = chưa init

# Bước 5 — Thực hiện init với 3 shares, threshold 2
vault operator init -key-shares=3 -key-threshold=2 \
  | tee /tmp/vault-init-lab/init-output.txt

# Đọc output và export unseal keys + root token
# (thay các giá trị thực tế từ file init-output.txt vào đây)
UNSEAL_KEY_1=$(grep 'Unseal Key 1:' /tmp/vault-init-lab/init-output.txt | awk '{print $NF}')
UNSEAL_KEY_2=$(grep 'Unseal Key 2:' /tmp/vault-init-lab/init-output.txt | awk '{print $NF}')
ROOT_TOKEN=$(grep 'Initial Root Token:' /tmp/vault-init-lab/init-output.txt | awk '{print $NF}')

# Bước 6 — Kiểm tra trạng thái sau init
vault status
# Kết quả: Initialized = true, Sealed = true

# Bước 7 — Unseal với 2 trong 3 keys
vault operator unseal "$UNSEAL_KEY_1"
# Kết quả: Sealed = true, Key Threshold = 2, Unseal Progress = 1/2

vault operator unseal "$UNSEAL_KEY_2"
# Kết quả: Sealed = false — Vault đã unsealed!

# Bước 8 — Đăng nhập và xác minh
vault login "$ROOT_TOKEN"

vault status
# Kết quả: Initialized = true, Sealed = false
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.

## Dọn dẹp sau bài lab (tùy chọn)

```bash
# Dừng Vault production server
pkill -f "vault server -config=/tmp/vault-init-lab/config.hcl"

# Xóa thư mục lab
rm -rf /tmp/vault-init-lab
```

> Lưu ý: không dọn dẹp trước khi chạy `bash verify.sh` — script cần Vault production server đang chạy để kiểm tra.
