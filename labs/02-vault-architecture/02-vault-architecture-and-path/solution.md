---
title: Đáp án mẫu — Vault Init và Unseal bằng Key Shards
---

# Đáp án mẫu

> Đây là một cách giải chuẩn. Có thể có nhiều cách khác — miễn là
> `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này thực hành quy trình mà dev mode bỏ qua:

1. **Init**: Vault tạo root key, encryption key, unseal keys (Shamir shares),
   và initial root token. Vault không lưu root key — mất đủ threshold keys
   đồng nghĩa mất Vault vĩnh viễn.

2. **Unseal**: Vault nhận từng key share, dùng Shamir Secret Sharing để
   reconstruct root key, dùng root key giải mã encryption key, nạp vào
   barrier. Chỉ sau khi đủ threshold keys thì barrier mới mở.

3. **Seal/Unseal lại**: Bất kỳ tổ hợp nào đủ threshold (2/3) đều hợp lệ.
   Sau khi seal, encryption key bị xóa khỏi memory ngay lập tức.

Điểm quan trọng cần ghi nhớ: dev mode (`-dev`) làm tất cả điều này tự động
và lưu dữ liệu trong memory. Production mode dùng storage bền vững (file,
Raft, Consul...) và yêu cầu unseal thủ công mỗi lần restart.

## Các lệnh

```bash
# Bước 1 — Tạo cấu hình
mkdir -p /tmp/vault-lab/data

cat > /tmp/vault-lab/config.hcl <<EOF
storage "file" {
  path = "/tmp/vault-lab/data"
}

listener "tcp" {
  address     = "127.0.0.1:8202"
  tls_disable = true
}

disable_mlock = true
EOF

# Bước 2 — Khởi động server
nohup vault server -config=/tmp/vault-lab/config.hcl >/tmp/vault-lab/server.log 2>&1 &
sleep 2

export VAULT_ADDR=http://127.0.0.1:8202
vault status
# Kết quả: Initialized: false, Sealed: true

# Bước 3 — Init với 3 shares, threshold 2
vault operator init -key-shares=3 -key-threshold=2 -format=json > /tmp/vault-lab/init-output.json
cat /tmp/vault-lab/init-output.json | jq '{unseal_keys: .unseal_keys_b64, root_token: .root_token}'

vault status
# Kết quả vẫn: Sealed: true (init không unseal)

# Bước 4 — Unseal key share 1
UNSEAL_KEY_1=$(cat /tmp/vault-lab/init-output.json | jq -r '.unseal_keys_b64[0]')
vault operator unseal "$UNSEAL_KEY_1"
# Output: Unseal Progress: 1/2, Sealed: true

# Bước 5 — Unseal key share 2
UNSEAL_KEY_2=$(cat /tmp/vault-lab/init-output.json | jq -r '.unseal_keys_b64[1]')
vault operator unseal "$UNSEAL_KEY_2"
# Output: Sealed: false — Vault đã unsealed!

# Bước 6 — Đăng nhập và kiểm tra
ROOT_TOKEN=$(cat /tmp/vault-lab/init-output.json | jq -r '.root_token')
vault login "$ROOT_TOKEN"

vault secrets list
vault secrets enable kv
vault kv put kv/test hello=world
vault kv get kv/test

# Bước 7 — Seal và unseal lại bằng key 1 và key 3
vault operator seal
vault status
# Kết quả: Sealed: true

UNSEAL_KEY_3=$(cat /tmp/vault-lab/init-output.json | jq -r '.unseal_keys_b64[2]')
vault operator unseal "$UNSEAL_KEY_1"
vault operator unseal "$UNSEAL_KEY_3"
vault status
# Kết quả: Sealed: false
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
