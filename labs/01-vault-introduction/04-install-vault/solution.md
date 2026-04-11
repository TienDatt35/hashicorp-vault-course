---
title: Đáp án mẫu — Khám phá Vault Dev Server trong Codespace
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này không yêu cầu bạn cài đặt hay cấu hình gì mới — Vault Dev Server đã được devcontainer khởi động sẵn. Mục tiêu là quan sát và xác nhận trực tiếp các đặc điểm của Dev Server mà bạn đã học trong lý thuyết: auto-init, auto-unseal, in-memory storage, KV v2 tại `secret/`, và UI sẵn sàng.

## Các lệnh

```bash
# Bước 1 — Kiểm tra trạng thái Vault
# Kết quả mong đợi: Initialized = true, Sealed = false, Storage Type = inmem
vault status

# Để xem dạng JSON (dễ đọc hơn cho script):
vault status -format=json
```

Output của `vault status` sẽ trông như sau:

```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.x.x
Storage Type    inmem
Cluster Name    vault-cluster-...
Cluster ID      ...
HA Enabled      false
```

Lưu ý: Dev Server chỉ có 1 key share và threshold là 1 (thay vì 5/3 của production) vì nó không cần bảo mật thực sự.

```bash
# Bước 2 — Kiểm tra phiên bản Vault
vault version
```

```bash
# Bước 3 — Xem danh sách secrets engines
# Tìm dòng secret/ với Type = kv và Options = [version:2]
vault secrets list

# Để xem chi tiết hơn ở dạng JSON:
vault secrets list -format=json
```

```bash
# Bước 4 — Ghi secret và đọc lại
# Ghi secret với key=value
vault kv put secret/hello foo=bar

# Đọc lại để xác nhận
vault kv get secret/hello
```

Output của `vault kv get secret/hello` sẽ hiển thị:

```
====== Secret Path ======
secret/data/hello

======= Metadata =======
Key              Value
---              -----
created_time     ...
version          1

====== Data ======
Key    Value
---    -----
foo    bar
```

```bash
# Bước 5 — Đọc config file HCL production mẫu
# Mở file để xem:
cat vault-production.hcl
```

**Trả lời 3 câu hỏi về vault-production.hcl:**

1. Block quy định nơi lưu trữ dữ liệu là `storage "raft"` — chỉ định `path = "/opt/vault/data"` là thư mục lưu dữ liệu trên disk.

2. Block quy định TLS certificate là `listener "tcp"` — chứa `tls_cert_file` và `tls_key_file` trỏ tới certificate và private key.

3. Giá trị của `api_addr` là `"https://vault.example.com:8200"` — đây là địa chỉ public mà Vault quảng bá cho client kết nối tới.

```bash
# Bước 6 — Chạy kiểm tra
bash verify.sh
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]` và dòng cuối `Tất cả kiểm tra đều đạt.`
