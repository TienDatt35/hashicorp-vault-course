---
title: "Đáp án: Khám phá giới hạn của Vault Community Edition"
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này khai thác một Vault dev server đang chạy ở chế độ Community Edition. Bằng cách thử lần lượt các lệnh — bao gồm một lệnh sẽ thất bại có chủ ý — bạn quan sát trực tiếp ranh giới giữa OSS và Enterprise. Tất cả thao tác đều dùng CLI `vault` là wrapper của HTTP API.

## Các lệnh

```bash
# Bước 1 — Kiểm tra phiên bản và trạng thái Vault
vault version
# Output ví dụ: Vault v1.18.x ('...'), built ...
# Lưu ý: không có '+ent' trong output → đang dùng Community Edition

vault status
# Xác nhận Vault sealed=false và đang chạy

# Bước 2 — Thử tạo namespace (sẽ thất bại với OSS)
vault namespace create test
# Output lỗi ví dụ:
#   Error making API request.
#   URL: POST http://127.0.0.1:8200/v1/sys/namespaces/test
#   Code: 404. Errors:
#   * 1 error occurred:
#     * no handler for route "sys/namespaces/test". ...
#
# Đây là hành vi đúng — OSS không có endpoint namespaces.
# Lỗi 404 "no handler for route" xác nhận tính năng này không tồn tại trong OSS.

# Bước 3 — Xem danh sách secrets engines
vault secrets list
# Các engine mặc định: cubbyhole/, identity/, secret/, sys/

# Bước 4 — Bật userpass auth method và tạo user
vault auth enable userpass
# Nếu đã bật rồi sẽ thấy: Error enabling userpass auth: path is already in use at userpass/
# Điều này không ảnh hưởng — bước tiếp theo vẫn chạy được

vault write auth/userpass/users/testuser password=testpass policies=default
# Tạo user testuser với password testpass và policy default

# Bước 5 — Bật KV v2 secrets engine tại path demo/
vault secrets enable -path=demo -version=2 kv
# Nếu đã bật rồi sẽ thấy: Error enabling: Error making API request. ... path is already in use
# Điều này không ảnh hưởng — secret vẫn có thể ghi và đọc

# Bước 6 — Ghi và đọc secret
vault kv put demo/test key=value
# Output: Key              Value
#         ---              -----
#         created_time     ...
#         ...

vault kv get demo/test
# Xác nhận key=value có trong output
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
