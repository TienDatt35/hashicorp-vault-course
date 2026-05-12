---
title: Đáp án mẫu — Khám phá Vault qua CLI, UI và HTTP API
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Ba cách tương tác với Vault:

1. **CLI** — lệnh `vault` là công cụ tiện lợi nhất trong quá trình học và
   debug. Mỗi lệnh CLI thực ra là một HTTP request đến endpoint `/v1/...`.

2. **UI** — giao diện web tại port 8200. Hữu ích để duyệt cấu hình, xem
   policies, và khám phá trực quan. Mọi thao tác trên UI đều là HTTP request
   phía sau — bật DevTools để thấy.

3. **HTTP API (curl)** — cách ứng dụng thực tế tích hợp Vault. Header
   `X-Vault-Token` mang token xác thực; body là JSON; response là JSON.

Token và capabilities: `vault token lookup` xem TTL và policies của token
đang dùng. `vault token capabilities <path>` kiểm tra quyền cụ thể tại một
path — hữu ích khi debug "tại sao tôi bị permission denied?".

## Các lệnh

```bash
# Bước 1 — Kiểm tra Vault
vault status

# Bước 2 — Xem thông tin token hiện tại
vault token lookup
# Chú ý: ttl=0 = root token không bao giờ hết hạn

# Bước 3 — Kiểm tra capabilities
vault token capabilities kv/data/app/db
# Kết quả: root

vault token capabilities sys/health
# Kết quả vẫn là root — root token không giới hạn path nào

# Bước 4 — UI: thực hiện thủ công theo hướng dẫn trong README

# Bước 5 — HTTP API

# Kiểm tra trạng thái (không cần token)
curl -s $VAULT_ADDR/v1/sys/health | jq '{initialized, sealed, standby}'

# Lookup root token
curl -s \
  -H "X-Vault-Token: root" \
  --request POST \
  --data '{"token": "root"}' \
  $VAULT_ADDR/v1/auth/token/lookup | jq '{policies: .data.policies, ttl: .data.ttl, type: .data.type}'

# Đọc secret kv/app/db
curl -s \
  -H "X-Vault-Token: root" \
  $VAULT_ADDR/v1/kv/data/app/db | jq .data.data

# Kiểm tra capabilities
curl -s \
  -H "X-Vault-Token: root" \
  --request POST \
  --data '{"token": "root", "path": "kv/data/app/db"}' \
  $VAULT_ADDR/v1/sys/capabilities | jq .

# Bước 6 — So sánh CLI vs API (output phải giống nhau)
vault kv get -format=json kv/app/db | jq .data.data
curl -s -H "X-Vault-Token: root" $VAULT_ADDR/v1/kv/data/app/db | jq .data.data
```

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
