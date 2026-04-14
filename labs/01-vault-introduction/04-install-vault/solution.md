---
title: "Đáp án — Cài Vault từ binary, cấu hình, khởi tạo và unseal"
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Miễn là `bash verify.sh` báo
> `[PASS]` cho mọi kiểm tra là đúng.

## Giải thích ngắn

Quy trình này đúng với cách cài Vault trên server Linux thực tế:
tải binary → copy vào PATH → viết config → khởi động → `operator init` →
`operator unseal` đủ threshold → login và kiểm tra.

Điểm quan trọng cần nắm:

- `operator init` chỉ chạy **một lần duy nhất** trên một Vault cluster.
- `operator unseal` phải chạy đúng **threshold** lần (ở đây là 2), mỗi lần
  một key khác nhau — đây là cơ chế Shamir Secret Sharing.
- Root token chỉ dùng trong lần đầu setup. Trong production, nên tạo token
  có phạm vi hẹp hơn và revoke root token sau khi cấu hình xong.

## Các lệnh

```bash
# Bước 1 — tạo thư mục làm việc
mkdir -p ~/vault-lab/data

# Bước 2 — tải, giải nén và cài binary vào /usr/local/bin
cd ~/vault-lab

curl -O https://releases.hashicorp.com/vault/1.21.4/vault_1.21.4_linux_386.zip

# Giải nén (cài unzip nếu chưa có)
apt-get install -y unzip 2>/dev/null || true
unzip vault_1.21.4_linux_386.zip

# Copy vào /usr/local/bin để dùng lệnh vault ngắn gọn
cp vault /usr/local/bin/vault

# Xác nhận
vault version
# Vault v1.21.4, built ...

# Bước 3 — copy config từ thư mục lab
# (chạy từ thư mục labs/01-vault-introduction/04-install-vault/)
cp vault-lab.hcl ~/vault-lab/config.hcl

# Xem lại config
cat ~/vault-lab/config.hcl

# Bước 4 — khởi động Vault server
nohup vault server -config=~/vault-lab/config.hcl \
  > ~/vault-lab/vault.log 2>&1 &

sleep 2

VAULT_ADDR=http://127.0.0.1:8300 vault status
# Initialized = false, Sealed = true

# Bước 5 — khởi tạo, lưu output
VAULT_ADDR=http://127.0.0.1:8300 \
  vault operator init \
  -key-shares=3 \
  -key-threshold=2 \
  | tee ~/vault-lab/init.txt

# Bước 6 — unseal (2 key bất kỳ trong 3)
# Cách nhập tay:
VAULT_ADDR=http://127.0.0.1:8300 vault operator unseal
VAULT_ADDR=http://127.0.0.1:8300 vault operator unseal

# Hoặc tự động từ init.txt:
UNSEAL_KEY_1=$(grep "Unseal Key 1" ~/vault-lab/init.txt | awk '{print $NF}')
UNSEAL_KEY_2=$(grep "Unseal Key 2" ~/vault-lab/init.txt | awk '{print $NF}')
VAULT_ADDR=http://127.0.0.1:8300 vault operator unseal "$UNSEAL_KEY_1"
VAULT_ADDR=http://127.0.0.1:8300 vault operator unseal "$UNSEAL_KEY_2"

# Bước 7 — đăng nhập và kiểm tra
ROOT_TOKEN=$(grep "Initial Root Token" ~/vault-lab/init.txt | awk '{print $NF}')
VAULT_ADDR=http://127.0.0.1:8300 vault login $ROOT_TOKEN

VAULT_ADDR=http://127.0.0.1:8300 vault status
# Initialized = true, Sealed = false, Storage Type = file

VAULT_ADDR=http://127.0.0.1:8300 vault secrets list
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
