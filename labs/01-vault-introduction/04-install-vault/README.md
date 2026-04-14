---
title: "Cài Vault từ binary, cấu hình, khởi tạo và unseal"
estMinutes: 30
---

# Cài Vault từ binary, cấu hình, khởi tạo và unseal

## Mục tiêu

Bạn sẽ tự tay cài Vault từ file binary, viết config file HCL, khởi động server,
thực hiện `operator init` để nhận unseal keys và root token, unseal server, rồi
xác nhận Vault hoạt động đúng.

Vault dev server đã chạy sẵn ở port `8200` trong Codespace — bài này bạn sẽ
cài và chạy một instance **riêng** ở port `8300` để trải nghiệm đúng quy trình
production.

## Yêu cầu

- Bạn đang ở trong Codespace của repo này.
- Có kết nối internet để tải binary.
- Đã đọc bài lý thuyết tương ứng.

## Nhiệm vụ của bạn

### Bước 1 — Chuẩn bị thư mục làm việc

Tạo thư mục `~/vault-lab/` để chứa binary, config và data:

```bash
mkdir -p ~/vault-lab/data
```

### Bước 2 — Tải và cài đặt Vault binary

Tải binary Vault 1.21.4 (linux 386) từ HashiCorp, giải nén và đặt vào
`~/vault-lab/vault`.

URL tải:
```
https://releases.hashicorp.com/vault/1.21.4/vault_1.21.4_linux_386.zip
```

Sau khi đặt xong, xác nhận binary hoạt động:

```bash
~/vault-lab/vault version
# Kết quả kỳ vọng: Vault v1.21.4, ...
```

### Bước 3 — Tạo config file

Tạo file `~/vault-lab/config.hcl` với nội dung sau. File này đã có sẵn trong
thư mục lab dưới tên `vault-lab.hcl` để bạn tham khảo.

```hcl
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
```

> Lưu ý: `tls_disable = 1` chỉ dùng cho mục đích học tập — không dùng trong
> production. `storage "file"` lưu dữ liệu trực tiếp ra disk (không cần Raft
> hay Consul).

### Bước 4 — Khởi động Vault server

Khởi động Vault ở background, ghi log ra file:

```bash
nohup ~/vault-lab/vault server -config=~/vault-lab/config.hcl \
  > ~/vault-lab/vault.log 2>&1 &
```

Chờ 2 giây rồi kiểm tra Vault đã lắng nghe ở port 8300:

```bash
sleep 2
VAULT_ADDR=http://127.0.0.1:8300 ~/vault-lab/vault status
# Kết quả kỳ vọng: Initialized = false, Sealed = true
# (server mới khởi động, chưa được init)
```

### Bước 5 — Khởi tạo Vault (`operator init`)

Khởi tạo Vault với 3 key shares, cần 2 key để unseal. **Lưu toàn bộ output
vào file** — bạn sẽ cần unseal keys và root token ở các bước tiếp theo:

```bash
VAULT_ADDR=http://127.0.0.1:8300 \
  ~/vault-lab/vault operator init \
  -key-shares=3 \
  -key-threshold=2 \
  | tee ~/vault-lab/init.txt
```

Output sẽ chứa:
- 3 `Unseal Key` (mỗi key trên một dòng)
- 1 `Initial Root Token`

> **Quan trọng**: trong production, các unseal keys phải được phân phát cho
> những người khác nhau và tuyệt đối không lưu cùng chỗ với Vault. Ở đây
> lưu vào file chỉ để phục vụ bài học.

### Bước 6 — Unseal Vault

Vault cần ít nhất **2 trong 3 key** để unseal. Chạy lệnh dưới đây **2 lần**,
mỗi lần nhập một key khác nhau từ file `init.txt`:

```bash
VAULT_ADDR=http://127.0.0.1:8300 ~/vault-lab/vault operator unseal
# Nhập Unseal Key 1, Enter
VAULT_ADDR=http://127.0.0.1:8300 ~/vault-lab/vault operator unseal
# Nhập Unseal Key 2, Enter
```

Sau lần thứ hai, trường `Sealed` chuyển thành `false` — Vault đã sẵn sàng.

### Bước 7 — Đăng nhập và kiểm tra

Lấy root token từ `init.txt` rồi đăng nhập:

```bash
ROOT_TOKEN=$(grep "Initial Root Token" ~/vault-lab/init.txt | awk '{print $NF}')
VAULT_ADDR=http://127.0.0.1:8300 VAULT_TOKEN=$ROOT_TOKEN \
  ~/vault-lab/vault status
```

Xác nhận hai thông tin:
- `Initialized: true`
- `Sealed: false`

Sau đó kiểm tra danh sách secrets engines mặc định:

```bash
VAULT_ADDR=http://127.0.0.1:8300 VAULT_TOKEN=$ROOT_TOKEN \
  ~/vault-lab/vault secrets list
```

Kỳ vọng thấy `cubbyhole/`, `identity/`, `secret/` và `sys/`.

> Gợi ý: hãy tự thực hành các bước trên trước khi xem `solution.md`.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
