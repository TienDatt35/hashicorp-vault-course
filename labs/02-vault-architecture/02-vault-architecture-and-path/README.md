---
title: Vault Init và Unseal bằng Key Shards
estMinutes: 25
---

# Vault Init và Unseal bằng Key Shards

## Mục tiêu

Bạn sẽ trải nghiệm trực tiếp quy trình khởi tạo và unseal một Vault
production server: từ trạng thái `uninitialized + sealed`, thực hiện
`vault operator init` để nhận unseal keys, sau đó unseal từng bước bằng
Shamir key shares. Đây là quy trình mà dev mode đã làm tự động — bài này
làm nó bằng tay.

## Yêu cầu

- Bạn đang làm việc trong Codespace của repo này.
- Vault dev server đang chạy ở port `8200` — bài này sẽ dùng **port 8202**
  để tránh xung đột.
- Bạn đã đọc bài lý thuyết "Vault Initialization" và "Unseal Vault bằng Key Shards".

## Nhiệm vụ của bạn

### Bước 1 — Tạo cấu hình Vault production server

Tạo thư mục và file cấu hình cho Vault server mới:

```bash
mkdir -p /tmp/vault-lab/data

cat > /tmp/vault-lab/config.hcl <<EOF
storage "file" {
  path = "/tmp/vault-lab/data"
}

listener "tcp" {
  address     = "127.0.0.1:8202"
  tls_disable = true
}

ui            = true
disable_mlock = true
EOF
```

### Bước 2 — Khởi động Vault server production mode

```bash
nohup vault server -config=/tmp/vault-lab/config.hcl >/tmp/vault-lab/server.log 2>&1 &
sleep 2
```

Trỏ VAULT_ADDR sang server mới:

```bash
export VAULT_ADDR=http://127.0.0.1:8202
```

Kiểm tra trạng thái — Vault phải ở trạng thái `Initialized: false, Sealed: true`:

```bash
vault status
```

### Bước 3 — Khởi tạo Vault (vault operator init)

Thực hiện init với 3 key shares và threshold là 2 (cần 2/3 keys để unseal):

```bash
vault operator init -key-shares=3 -key-threshold=2 -format=json > /tmp/vault-lab/init-output.json
```

Lưu init output ra file để dùng cho các bước tiếp theo. Xem nội dung:

```bash
cat /tmp/vault-lab/init-output.json | jq '{unseal_keys: .unseal_keys_b64, root_token: .root_token}'
```

Ghi nhận: Vault tạo ra 3 unseal keys và 1 root token. **Trong production,
phải lưu trữ các keys này an toàn và phân phối cho nhiều người khác nhau.**

Kiểm tra trạng thái sau init — vẫn còn `Sealed: true`:

```bash
vault status
```

### Bước 4 — Unseal từng bước (Bước 1/2)

Lấy unseal key thứ nhất từ file init output và nộp vào:

```bash
UNSEAL_KEY_1=$(cat /tmp/vault-lab/init-output.json | jq -r '.unseal_keys_b64[0]')
vault operator unseal "$UNSEAL_KEY_1"
```

Đọc output và chú ý dòng `Unseal Progress: 1/2`. Vault đã nhận 1 key nhưng
chưa đủ threshold — vẫn còn `Sealed: true`.

### Bước 5 — Unseal từng bước (Bước 2/2)

Nộp unseal key thứ hai:

```bash
UNSEAL_KEY_2=$(cat /tmp/vault-lab/init-output.json | jq -r '.unseal_keys_b64[1]')
vault operator unseal "$UNSEAL_KEY_2"
```

Sau khi nộp key thứ 2, Vault phải chuyển sang `Sealed: false`. Bạn vừa
hoàn thành quá trình unseal — barrier đã nhận encryption key vào memory.

### Bước 6 — Đăng nhập bằng initial root token

```bash
VAULT_TOKEN=$(cat /tmp/vault-lab/init-output.json | jq -r '.root_token')
vault login "$VAULT_TOKEN"
```

Xác nhận login thành công và thấy `policies: [root]`.

Thử một thao tác đơn giản để xác nhận Vault hoạt động sau unseal:

```bash
vault secrets list
vault secrets enable kv
vault kv put kv/test hello=world
vault kv get kv/test
```

### Bước 7 — Seal và Unseal lại

Seal Vault để xóa encryption key khỏi memory:

```bash
vault operator seal
```

Kiểm tra trạng thái — `Sealed: true`. Unseal progress về `0/2`.

Unseal lại bằng key 1 và key 3 (thay vì key 1 và key 2 như lần trước —
bất kỳ 2/3 keys đều hợp lệ):

```bash
UNSEAL_KEY_1=$(cat /tmp/vault-lab/init-output.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_3=$(cat /tmp/vault-lab/init-output.json | jq -r '.unseal_keys_b64[2]')
vault operator unseal "$UNSEAL_KEY_1"
vault operator unseal "$UNSEAL_KEY_3"
```

Xác nhận `Sealed: false` một lần nữa.

> Gợi ý: nếu bí ở bất kỳ bước nào, hãy mở `solution.md` để đối chiếu.

## Tiêu chí thành công

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Dọn dẹp sau bài lab

Sau khi hoàn thành, bạn có thể dọn dẹp:

```bash
pkill -f "vault server -config=/tmp/vault-lab" || true
rm -rf /tmp/vault-lab
```

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
