---
title: "Cài Vault từ binary, cấu hình, khởi tạo và unseal"
estMinutes: 30
---

# Cài Vault từ binary, cấu hình, khởi tạo và unseal

## Mục tiêu

Bạn sẽ tự tay cài Vault từ file binary, viết config file HCL theo cấu trúc
production, khởi động server, thực hiện `operator init` để nhận unseal keys và
root token, unseal server, rồi xác nhận Vault hoạt động đúng.

Vault dev server đã chạy sẵn ở port `8200` trong Codespace — bài này bạn sẽ
cài và chạy một instance **riêng** ở port `8300`.

## Yêu cầu

- Bạn đang ở trong Codespace của repo này.
- Có kết nối internet để tải binary.
- Đã đọc bài lý thuyết tương ứng.

## Nhiệm vụ của bạn

### Bước 1 — Chuẩn bị thư mục làm việc

Tạo thư mục để chứa config, data và log:

```bash
mkdir -p ~/vault-lab/data
```

### Bước 2 — Tải, giải nén và cài binary

Tải binary Vault 1.21.4 (linux 386), giải nén rồi copy vào `/usr/local/bin`
để dùng lệnh `vault` ngắn gọn từ bất kỳ đâu:

```
https://releases.hashicorp.com/vault/1.21.4/vault_1.21.4_linux_386.zip
```

Sau khi cài xong, xác nhận:

```bash
vault version
# Kết quả kỳ vọng: Vault v1.21.4, ...
```

### Bước 3 — Tạo config file

Sao chép file `vault-lab.hcl` từ thư mục lab này ra `~/vault-lab/config.hcl`.
File đã có cấu trúc giống production với `cluster_addr`, `api_addr`,
`storage "file"` và `listener "tcp"` (TLS tắt để đơn giản).

```bash
cp vault-lab.hcl ~/vault-lab/config.hcl
```

Xem lại nội dung file trước khi tiếp tục:

```bash
cat ~/vault-lab/config.hcl
```

> So sánh với `vault-production.hcl` trong cùng thư mục để thấy điểm khác
> biệt duy nhất là `tls_disable = 1` thay vì `tls_cert_file` / `tls_key_file`.

### Bước 4 — Khởi động Vault server

```bash
nohup vault server -config=~/vault-lab/config.hcl \
  > ~/vault-lab/vault.log 2>&1 &

sleep 2

VAULT_ADDR=http://127.0.0.1:8300 vault status
# Kết quả kỳ vọng: Initialized = false, Sealed = true
```

### Bước 5 — Khởi tạo Vault (`operator init`)

Khởi tạo với 3 key shares, threshold 2. **Lưu toàn bộ output vào file**:

```bash
VAULT_ADDR=http://127.0.0.1:8300 \
  vault operator init \
  -key-shares=3 \
  -key-threshold=2 \
  | tee ~/vault-lab/init.txt
```

Output chứa 3 `Unseal Key` và 1 `Initial Root Token`.

> **Quan trọng**: trong production, các unseal keys phải được phân phát cho
> những người khác nhau và tuyệt đối không lưu cùng chỗ với Vault.

### Bước 6 — Unseal Vault

Cần ít nhất **2 trong 3 key** để unseal. Chạy lệnh **2 lần**, mỗi lần nhập
một key khác nhau:

```bash
VAULT_ADDR=http://127.0.0.1:8300 vault operator unseal
# Nhập Unseal Key 1, Enter

VAULT_ADDR=http://127.0.0.1:8300 vault operator unseal
# Nhập Unseal Key 2, Enter
```

Sau lần thứ hai: `Sealed = false`.

### Bước 7 — Đăng nhập và kiểm tra

```bash
ROOT_TOKEN=$(grep "Initial Root Token" ~/vault-lab/init.txt | awk '{print $NF}')

VAULT_ADDR=http://127.0.0.1:8300 vault login $ROOT_TOKEN

VAULT_ADDR=http://127.0.0.1:8300 vault status
# Initialized = true, Sealed = false, Storage Type = file

VAULT_ADDR=http://127.0.0.1:8300 vault secrets list
# cubbyhole/, identity/, secret/, sys/
```

> Gợi ý: tự thực hành các bước trên trước khi xem `solution.md`.

## Tiêu chí thành công

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
