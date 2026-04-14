---
title: Auto Unseal với KMS — Cấu hình và Nhận biết
estMinutes: 20
---

# Auto Unseal với KMS — Cấu hình và Nhận biết

## Mục tiêu

Nhận biết sự khác biệt giữa Shamir seal và Auto Unseal qua output của `vault status`, viết file cấu hình Vault với `seal` stanza cho AWS KMS và Azure Key Vault, và hiểu điều gì xảy ra khi Vault không kết nối được KMS.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/02-vault-architecture/05-auto-unseal/`.

**Lưu ý quan trọng**: Bài lab này tập trung vào nhận biết cấu hình và đọc output — bạn không cần tài khoản cloud thật. Môi trường production với KMS thật đòi hỏi cloud resources nằm ngoài phạm vi bài này.

## Nhiệm vụ của bạn

### Bước 1 — Khảo sát Vault dev server hiện tại

Chạy lệnh sau và quan sát output:

```bash
vault status
```

Ghi nhận các trường sau và suy nghĩ về ý nghĩa của chúng trong ngữ cảnh Auto Unseal:
- `Seal Type` đang là gì?
- `Sealed` đang là gì?
- Có trường `Recovery Seal` không?

### Bước 2 — Tạo file cấu hình Vault với seal "awskms"

Tạo file `/tmp/vault-awskms.hcl` với nội dung là một cấu hình Vault hợp lệ bao gồm:
- Một `storage` stanza (dùng `file` backend với path `/tmp/vault-data`)
- Một `listener` stanza (TCP trên `127.0.0.1:8300`, `tls_disable = true`)
- Một `seal` stanza cho AWS KMS với:
  - `region = "ap-southeast-1"`
  - `kms_key_id = "mrk-00000000000000000000000000000001"`

Bạn cần tự viết file này dựa trên kiến thức từ bài lý thuyết.

### Bước 3 — Khởi động Vault với cấu hình KMS và quan sát lỗi

Chạy lệnh sau để thử khởi động một Vault server thứ hai với cấu hình KMS:

```bash
vault server -config=/tmp/vault-awskms.hcl 2>&1 | head -20
```

Vault sẽ gặp lỗi vì không có KMS thật. Đọc thông báo lỗi và trả lời cho bản thân: lỗi xảy ra ở giai đoạn nào? Tại sao Vault không thể tiếp tục khởi động?

> Gợi ý: Vault cần gọi KMS ngay khi khởi động. Không có KMS thật nghĩa là không có gì xảy ra ở bước đó.

### Bước 4 — Đọc và phân tích output vault status trong KMS mode

Vault dev server hiện tại dùng Shamir. Dưới đây là một output mẫu của `vault status` khi Vault đang dùng AWS KMS (đã unsealed thành công):

```
Key                       Value
---                       -----
Seal Type                 awskms
Initialized               true
Sealed                    false
Recovery Seal             true
Total Recovery Shares     5
Recovery Threshold        3
Version                   1.18.0
```

Tạo file `/tmp/vault-status-analysis.txt` và trả lời các câu hỏi sau bên trong file đó:
1. Trường nào cho biết đây là Auto Unseal chứ không phải Shamir?
2. Nếu `Sealed = true` trong output này, nguyên nhân có thể là gì?
3. Recovery Threshold là 3, nghĩa là cần bao nhiêu recovery shares để thực hiện `vault operator generate-root`?

### Bước 5 — Bài tập viết: seal stanza cho Azure Key Vault

Tạo file `/tmp/vault-azurekeyvault.hcl` với cấu hình Vault đầy đủ sử dụng Azure Key Vault làm seal provider. Sử dụng thông tin sau:

- `tenant_id`: `11111111-2222-3333-4444-555555555555`
- `client_id`: `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee`
- `client_secret`: `MySecretValue123`
- `vault_name`: `my-company-vault`
- `key_name`: `vault-master-key`
- `storage`: file backend, path `/tmp/vault-azure-data`
- `listener`: TCP, `127.0.0.1:8400`, `tls_disable = true`

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần
> giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
