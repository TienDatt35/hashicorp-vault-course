---
title: Đáp án — Unseal Vault bằng Key Shards
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Vault dev server tự động init và unseal khi khởi động, nên bạn không thể quan sát quy trình này. Bài lab chuyển sang production mode với file storage để trải nghiệm đầy đủ vòng đời: `init` → `sealed` → `unseal từng bước` → `unsealed`.

Điểm quan trọng cần nhớ sau bài này:
- Sau `vault operator init`, Vault vẫn đang ở trạng thái sealed — init chỉ tạo ra keys, không tự unseal.
- Mỗi lần `vault operator unseal` nộp một share, Vault cộng dần progress.
- Khi đạt threshold (ở đây là 2/3), Vault tự động reconstruct root key và decrypt encryption key vào memory.

## Các lệnh

```bash
# Bước 1 — Kiểm tra dev server đang chạy
vault status

# Bước 2 — Dừng Vault dev server
pkill -f "vault server -dev" || true
# Đợi tiến trình dừng hẳn
sleep 2

# Bước 3 — Tạo thư mục và config file
mkdir -p /tmp/vault-lab/data

cat > /tmp/vault-lab/config.hcl << 'EOF'
storage "file" {
  path = "/tmp/vault-lab/data"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
}

disable_mlock = true
EOF

# Bước 4 — Khởi động Vault production mode ở background
vault server -config=/tmp/vault-lab/config.hcl > /tmp/vault-lab/vault.log 2>&1 &
# Đợi server sẵn sàng
sleep 3

# Xác nhận server đang chạy và chưa init
vault status
# Output mong đợi: Initialized = false, Sealed = true

# Bước 5 — Khởi tạo Vault với 3 shares, threshold 2
vault operator init -key-shares=3 -key-threshold=2
# Lưu lại toàn bộ output!
# Output mẫu:
#   Unseal Key 1: <key1>
#   Unseal Key 2: <key2>
#   Unseal Key 3: <key3>
#   Initial Root Token: <token>

# --- Lưu keys vào biến môi trường để dùng trong bài lab ---
# (Thay <key1>, <key2>, <token> bằng giá trị thực từ output ở trên)
UNSEAL_KEY_1="<key1>"
UNSEAL_KEY_2="<key2>"
ROOT_TOKEN="<token>"

# Bước 6a — Nộp Unseal Key đầu tiên
vault operator unseal "$UNSEAL_KEY_1"
# Xem progress thay đổi
vault status
# Output: Sealed = true, Unseal Progress = 1/2

# Bước 6b — Nộp Unseal Key thứ hai (đạt threshold)
vault operator unseal "$UNSEAL_KEY_2"
# Output: Sealed = false — Vault đã unsealed!
vault status
# Output: Sealed = false, Unseal Progress = 0/2

# Bước 7 — Đăng nhập bằng root token
export VAULT_TOKEN="$ROOT_TOKEN"
vault status
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.

## Dọn dẹp sau bài lab (tùy chọn)

Sau khi hoàn thành, devcontainer sẽ tự khởi động lại Vault dev server khi bạn mở Codespace lần tiếp. Tuy nhiên nếu muốn khôi phục ngay:

```bash
# Dừng vault production mode
pkill -f "vault server -config" || true

# Khởi động lại dev server như devcontainer thường làm
nohup vault server -dev -dev-root-token-id=root > /tmp/vault.log 2>&1 &
sleep 3
export VAULT_TOKEN=root
vault status
```
