---
title: Đáp án mẫu — Khám phá các thành phần cốt lõi của Vault
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này đi qua ba thành phần chính của Vault theo đúng thứ tự một operator thường làm khi cấu hình Vault lần đầu:

1. **Secrets Engine**: nơi secrets thật sự được lưu hoặc sinh ra — cần enable trước khi ghi bất kỳ secret nào.
2. **Auth Method**: cổng xác thực — enable để các user/app có thể lấy token mà không cần dùng root token.
3. **Audit Device**: nhật ký bất biến — enable ngay từ đầu để mọi thao tác đều được ghi lại, kể cả các thao tác trong quá trình cấu hình.

## Các lệnh

```bash
# Bước 1 — Thiết lập biến môi trường và kiểm tra Vault
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'
vault status

# Bước 2a — Enable KV secrets engine tại path "secret/"
# KV engine không có path mặc định là "secret/" — phải chỉ định rõ bằng -path
vault secrets enable -path=secret kv

# Bước 2b — Enable thêm một instance KV tại path "kv-dev/"
vault secrets enable -path=kv-dev kv

# Bước 2c — Xác nhận cả hai engine đã xuất hiện
vault secrets list

# Bước 2d — Ghi một secret vào secret/my-app
# Lệnh "vault kv put" dùng cho KV v1; key=value là cú pháp chuẩn
vault kv put secret/my-app password=supersecret

# Bước 2e — Đọc lại secret để xác nhận
vault kv get secret/my-app

# Bước 3a — Enable userpass auth method
vault auth enable userpass

# Bước 3b — Tạo user alice với password và gán policy default
# "policies=default" gán policy default — user sẽ có quyền cơ bản nhất
vault write auth/userpass/users/alice password=password123 policies=default

# Bước 3c — Liệt kê auth methods để xác nhận
vault auth list

# Bước 4a — Enable audit device loại file
# Vault cần quyền ghi vào /tmp/vault-audit.log
vault audit enable file file_path=/tmp/vault-audit.log

# Bước 4b — Xác nhận audit device đang bật
vault audit list

# Bước 5 — Thực hiện một thao tác để kiểm tra audit log
vault kv get secret/my-app

# Xem 5 dòng đầu của audit log để xác nhận ghi log hoạt động
cat /tmp/vault-audit.log | head -5
```

## Giải thích chi tiết

**Tại sao phải dùng `-path=secret` khi enable KV?**

Lệnh `vault secrets enable kv` không chỉ định path sẽ mount engine tại path `kv/` (tên engine làm path mặc định). Nếu muốn mount tại `secret/`, bạn phải dùng `vault secrets enable -path=secret kv`. Trong Vault dev server, `secret/` thường đã được enable sẵn — nếu nhận lỗi "path is already in use", hãy bỏ qua bước enable và tiếp tục ghi secret.

**Tại sao audit log chứa hash thay vì plaintext?**

Khi xem nội dung `/tmp/vault-audit.log`, bạn sẽ thấy token value và password được hash bằng HMAC-SHA256 thay vì lưu plaintext. Đây là thiết kế bảo mật của Vault — kể cả admin có quyền đọc audit log cũng không thể khôi phục token value gốc từ log.

**Tại sao enable audit device sau khi thao tác?**

Trong thực tế, bạn nên enable audit device **trước** mọi thao tác khác để có full audit trail. Trong bài thực hành này thứ tự được đảo để học từng thành phần theo logic (secrets engine → auth method → audit), nhưng `verify.sh` kiểm tra trạng thái cuối cùng nên thứ tự không ảnh hưởng đến kết quả.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
