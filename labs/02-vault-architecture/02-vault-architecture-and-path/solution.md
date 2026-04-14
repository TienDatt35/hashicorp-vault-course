---
title: Đáp án mẫu — Kiến Trúc Vault và Path-based Routing
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này minh họa trực tiếp hai khái niệm cốt lõi trong lý thuyết: path-based routing và reserved paths. Khi bạn enable engine tại `myapp/`, Vault router ghi nhận prefix này và forward mọi request có prefix `myapp/` tới đúng engine đó. System Backend tại `sys/` luôn tồn tại và không thể unmount — đây là "hệ thần kinh trung ương" của Vault. Reserved paths như `cubbyhole/` được bảo vệ cứng ở tầng router.

## Các lệnh

### Bước 1 — Kiểm tra Vault và xem mount hiện tại

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Xem trạng thái Vault
vault status

# Xem tất cả secrets engines đang mount
vault secrets list

# Xem tất cả auth methods đang enable
vault auth list
```

Trong dev mode, bạn sẽ thấy mặc định có `cubbyhole/`, `identity/`, `secret/` (KV v2), và `sys/` trong secrets list. Auth list có sẵn `token/`. Đây là các mount được Vault tự khởi tạo khi chạy dev server.

### Bước 2 — Enable secrets engine tại custom path

```bash
# Enable KV engine tại path tùy chỉnh myapp/
vault secrets enable -path=myapp kv

# Xác nhận mount xuất hiện
vault secrets list

# Ghi secret vào engine qua path myapp/
vault kv put myapp/config db_host=localhost

# Đọc lại secret
vault kv get myapp/config
```

Bạn dùng `myapp/config` vì engine được mount tại `myapp/` — đây là prefix mà Vault dùng để route request. Nếu bạn gõ `kv/config`, Vault sẽ tìm engine ở `kv/` (một mount khác, hoặc không tồn tại). Path-based routing hoạt động thuần túy theo prefix.

### Bước 3 — Khám phá System Backend qua `sys/`

```bash
# Đọc thông tin mount qua CLI
vault read sys/mounts

# Hoặc gọi REST API trực tiếp
curl -s -H "X-Vault-Token: root" http://127.0.0.1:8200/v1/sys/mounts | python3 -m json.tool | head -60
```

Output của `vault read sys/mounts` trả về thông tin đầy đủ về từng mount: type, accessor, config options. Đây chính là dữ liệu mà `vault secrets list` hiển thị ở dạng rút gọn. Lệnh `vault secrets list` thực chất chỉ là wrapper gọi `GET /v1/sys/mounts`.

### Bước 4 — Thử mount vào reserved path (kết quả mong đợi là lỗi)

```bash
# Lệnh này sẽ báo lỗi — đây là hành vi đúng
vault secrets enable -path=cubbyhole kv
```

Vault sẽ trả về lỗi tương tự:
```
Error enabling: Error making API request.
...
* existing mount at cubbyhole/
```

Lỗi này xác nhận rằng `cubbyhole/` là reserved path đã được mount sẵn bởi Vault và không thể dùng cho user-defined mount. Bạn không cần làm gì thêm ở bước này — quan sát lỗi là mục tiêu.

### Bước 5 — Enable auth method tại custom path

```bash
# Enable userpass auth method tại custom path my-userpass
vault auth enable -path=my-userpass userpass

# Xác nhận xuất hiện trong danh sách với prefix auth/my-userpass/
vault auth list

# Tạo user alice với password và policy
vault write auth/my-userpass/users/alice \
  password=password123 \
  policies=default

# Login với alice qua custom path
vault login -method=userpass -path=my-userpass username=alice password=password123
```

Lưu ý `-path=my-userpass` trong lệnh `vault login`: bạn phải chỉ định đúng path của auth method vì Vault cần biết forward request tới mount nào. Nếu bỏ `-path`, Vault sẽ mặc định dùng `userpass/` và báo lỗi vì mount đó không tồn tại.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
