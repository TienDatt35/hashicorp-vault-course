---
title: "Đáp án — Cài Vault từ binary, cấu hình, khởi tạo và unseal"
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Miễn là `bash verify.sh` báo
> `[PASS]` cho mọi kiểm tra là đúng.

## Giải thích ngắn

Bài này đi qua đúng quy trình production của một Vault instance mới:
tải binary → viết config → khởi động server → `operator init` (tạo unseal keys
và root token) → `operator unseal` (cần đủ threshold) → login và kiểm tra.

Điểm quan trọng cần nắm:

- `operator init` chỉ chạy **một lần duy nhất** trên một Vault cluster. Sau
  đó Vault sẽ từ chối mọi lần init tiếp theo.
- `operator unseal` phải chạy **nhiều lần** (đúng bằng threshold). Mỗi lần
  cung cấp một key khác nhau — đây là cơ chế Shamir Secret Sharing.
- Root token chỉ dùng trong lần đầu setup. Trong production, nên tạo token
  có phạm vi hẹp hơn và revoke root token sau khi cấu hình xong.

## Các lệnh

```bash
# Bước 1 — tạo thư mục làm việc
mkdir -p ~/vault-lab/data

# Bước 2 — tải binary, giải nén và đặt vào ~/vault-lab/
cd ~/vault-lab

curl -O https://releases.hashicorp.com/vault/1.21.4/vault_1.21.4_linux_386.zip

# Giải nén (cần unzip; nếu chưa có: sudo apt-get install -y unzip)
unzip vault_1.21.4_linux_386.zip

# Xác nhận binary hoạt động
~/vault-lab/vault version
# Kết quả: Vault v1.21.4, built ...

# Bước 3 — tạo config file
cat > ~/vault-lab/config.hcl <<'EOF'
ui            = true
api_addr      = "http://127.0.0.1:8300"
disable_mlock = true

storage "file" {
  path = "/root/vault-lab/data"
}

listener "tcp" {
  address     = "127.0.0.1:8300"
  tls_disable = 1
}
EOF

# Bước 4 — khởi động Vault server ở background
nohup ~/vault-lab/vault server -config=~/vault-lab/config.hcl \
  > ~/vault-lab/vault.log 2>&1 &

sleep 2

# Xác nhận server đang lắng nghe (Initialized=false, Sealed=true là đúng)
VAULT_ADDR=http://127.0.0.1:8300 ~/vault-lab/vault status

# Bước 5 — khởi tạo Vault, lưu toàn bộ output
VAULT_ADDR=http://127.0.0.1:8300 \
  ~/vault-lab/vault operator init \
  -key-shares=3 \
  -key-threshold=2 \
  | tee ~/vault-lab/init.txt

# Output mẫu:
# Unseal Key 1: abc123...
# Unseal Key 2: def456...
# Unseal Key 3: ghi789...
#
# Initial Root Token: hvs.XXXXXXXXXXXX
#
# Vault initialized with 3 key shares and a key threshold of 2.

# Bước 6 — unseal: cần đúng 2 key (bất kỳ 2 trong 3)
# Chạy lệnh đầu tiên, paste Unseal Key 1 khi được hỏi
VAULT_ADDR=http://127.0.0.1:8300 ~/vault-lab/vault operator unseal

# Chạy lệnh thứ hai, paste Unseal Key 2 khi được hỏi
VAULT_ADDR=http://127.0.0.1:8300 ~/vault-lab/vault operator unseal

# Sau lần thứ hai: Sealed = false

# Nếu muốn tự động hoá (không nhập tay):
# UNSEAL_KEY_1=$(grep "Unseal Key 1" ~/vault-lab/init.txt | awk '{print $NF}')
# UNSEAL_KEY_2=$(grep "Unseal Key 2" ~/vault-lab/init.txt | awk '{print $NF}')
# VAULT_ADDR=http://127.0.0.1:8300 ~/vault-lab/vault operator unseal "$UNSEAL_KEY_1"
# VAULT_ADDR=http://127.0.0.1:8300 ~/vault-lab/vault operator unseal "$UNSEAL_KEY_2"

# Bước 7 — đăng nhập và kiểm tra
ROOT_TOKEN=$(grep "Initial Root Token" ~/vault-lab/init.txt | awk '{print $NF}')

VAULT_ADDR=http://127.0.0.1:8300 VAULT_TOKEN=$ROOT_TOKEN \
  ~/vault-lab/vault status
# Kết quả: Initialized=true, Sealed=false, Storage Type=file

VAULT_ADDR=http://127.0.0.1:8300 VAULT_TOKEN=$ROOT_TOKEN \
  ~/vault-lab/vault secrets list
# Kết quả: cubbyhole/, identity/, secret/, sys/
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
