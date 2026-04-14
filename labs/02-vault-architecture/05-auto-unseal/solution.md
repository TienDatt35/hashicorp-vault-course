---
title: Đáp án mẫu — Auto Unseal với KMS
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài lab này không cần KMS thật mà tập trung vào hai kỹ năng: (1) đọc và phân tích output của `vault status` để phân biệt Shamir mode và Auto Unseal mode, và (2) viết đúng cú pháp `seal` stanza trong file cấu hình HCL của Vault. Đây là kỹ năng thiết yếu khi làm việc với Vault production vì bạn thường phải đọc config và status của người khác để debug.

## Bước 1 — Khảo sát Vault dev server

```bash
vault status
```

Output bạn sẽ thấy với Vault dev server:

```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.18.x
...
```

Nhận xét:
- `Seal Type: shamir` — đây là Shamir Secret Sharing (manual unseal mode).
- Không có trường `Recovery Seal` — chỉ xuất hiện khi dùng Auto Unseal.
- Dev server dùng 1 share / threshold 1 nên tự unseal ngay, không phản ánh production.

## Bước 2 — File cấu hình Vault với seal "awskms"

Tạo file `/tmp/vault-awskms.hcl`:

```bash
cat > /tmp/vault-awskms.hcl << 'EOF'
storage "file" {
  path = "/tmp/vault-data"
}

listener "tcp" {
  address     = "127.0.0.1:8300"
  tls_disable = true
}

seal "awskms" {
  region     = "ap-southeast-1"
  kms_key_id = "mrk-00000000000000000000000000000001"
}
EOF
```

Giải thích từng stanza:
- `storage "file"` — lưu dữ liệu Vault vào filesystem. Không dùng cho production nhưng đủ để thử nghiệm cú pháp.
- `listener "tcp"` — Vault lắng nghe trên port 8300 (tránh xung đột với dev server đang chạy trên 8200). `tls_disable = true` chỉ dùng cho lab/test.
- `seal "awskms"` — khai báo Auto Unseal với AWS KMS. `region` là vùng AWS, `kms_key_id` là ID của KMS key.

## Bước 3 — Quan sát lỗi khi không có KMS

```bash
vault server -config=/tmp/vault-awskms.hcl 2>&1 | head -20
```

Vault sẽ báo lỗi tương tự:

```
==> Vault server configuration:

             Api Address: http://127.0.0.1:8300
                     Cgo: disabled
         Cluster Address: https://127.0.0.1:8301
...
==> Vault server started! Log data will stream in below:

[ERROR] core: failed to unseal: error="error fetching stored keys: failed to decrypt keys:
  awskms: error decrypting data: operation error KMS: Decrypt,
  https response error StatusCode: 400 ..."
```

Hoặc lỗi có thể xuất hiện ngay khi Vault khởi động nếu không có AWS credentials:

```
[ERROR] seal.awskms: error initializing awskms seal: ...
  NoCredentialProviders: no valid providers in chain
```

Phân tích: Vault cố gắng gọi AWS KMS API ngay khi khởi động (hoặc khi init) để decrypt encrypted root key. Không có KMS thật hoặc không có AWS credentials hợp lệ, Vault không thể hoàn thành bước này và ở lại trạng thái sealed. Đây chính là điểm yếu của Auto Unseal — phụ thuộc vào tính khả dụng của KMS.

## Bước 4 — File phân tích vault status

```bash
cat > /tmp/vault-status-analysis.txt << 'EOF'
1. Trường nào cho biết đây là Auto Unseal chứ không phải Shamir?
   - Seal Type = "awskms" (không phải "shamir")
   - Recovery Seal = true (chỉ xuất hiện với Auto Unseal)
   - Các trường "Total Recovery Shares" và "Recovery Threshold" thay thế
     cho "Total Shares" và "Threshold" của Shamir

2. Nếu Sealed = true trong output này, nguyên nhân có thể là gì?
   - KMS không truy cập được (sự cố mạng, IAM permissions bị thu hồi)
   - KMS key bị disable tạm thời
   - KMS key bị xóa vĩnh viễn (trường hợp nghiêm trọng nhất)
   - Vault vừa mới khởi động và chưa hoàn thành quá trình unseal

3. Recovery Threshold là 3, cần bao nhiêu recovery shares để thực hiện
   vault operator generate-root?
   - Cần đúng 3 recovery shares (bằng với Recovery Threshold).
   - Quorum 3/5 phải đồng ý để thực hiện thao tác đặc quyền này.
EOF
```

## Bước 5 — File cấu hình Azure Key Vault

```bash
cat > /tmp/vault-azurekeyvault.hcl << 'EOF'
storage "file" {
  path = "/tmp/vault-azure-data"
}

listener "tcp" {
  address     = "127.0.0.1:8400"
  tls_disable = true
}

seal "azurekeyvault" {
  tenant_id     = "11111111-2222-3333-4444-555555555555"
  client_id     = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  client_secret = "MySecretValue123"
  vault_name    = "my-company-vault"
  key_name      = "vault-master-key"
}
EOF
```

Lưu ý quan trọng cho production: không nên hardcode `client_secret` trong file config. Trong môi trường thực tế trên Azure, hãy dùng Managed Service Identity (MSI) để loại bỏ hoàn toàn việc quản lý credentials.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
