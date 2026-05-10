---
title: Đáp án mẫu — Các loại Token
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này đi qua 5 loại token: service, batch, periodic, orphan, và token được tạo qua role (token store role và AppRole). Mỗi loại có hành vi vòng đời khác nhau — batch không thể renew, periodic reset TTL khi renew, orphan không bị revoke theo cha.

## Các lệnh

### Bước 1 — Service token và batch token

```bash
# Tạo service token
vault token create -policy=default -ttl=30m

# Tạo batch token và lưu vào biến
BATCH_TOKEN=$(vault token create -type=batch -ttl=10m -policy=default -format=json | jq -r '.auth.client_token')
echo "Batch token: $BATCH_TOKEN"
# Prefix phải là hvb.

# Thử renew batch token — sẽ thất bại
vault token renew "$BATCH_TOKEN"
# Error: ... batch tokens cannot be renewed

export BATCH_TOKEN
```

### Bước 2 — Periodic token

```bash
# Tạo periodic token
PERIODIC_TOKEN=$(vault token create -period=2m -policy=default -format=json | jq -r '.auth.client_token')

# Lưu accessor
PERIODIC_ACCESSOR=$(vault token lookup -format=json "$PERIODIC_TOKEN" | jq -r '.data.accessor')
echo "Periodic accessor: $PERIODIC_ACCESSOR"

# Kiểm tra expire_time (phải trống hoặc n/a) và period (phải là 2m)
vault token lookup -format=json "$PERIODIC_TOKEN" | jq '.data | {period, expire_time, ttl}'

# Chờ khoảng 30 giây rồi renew
sleep 30
vault token renew "$PERIODIC_TOKEN"

# Kiểm tra lại TTl — đã reset về gần 2m
vault token lookup -format=json "$PERIODIC_TOKEN" | jq '.data.ttl'

export PERIODIC_ACCESSOR
```

### Bước 3 — Cascade revocation và orphan token

```bash
# Tạo parent token
PARENT_TOKEN=$(vault token create -policy=default -ttl=10m -format=json | jq -r '.auth.client_token')
echo "Parent token: $PARENT_TOKEN"

# Tạo child token từ parent token
CHILD_TOKEN=$(VAULT_TOKEN="$PARENT_TOKEN" vault token create -policy=default -ttl=10m -format=json | jq -r '.auth.client_token')
echo "Child token: $CHILD_TOKEN"

# Tạo orphan token (dùng root token)
ORPHAN_TOKEN=$(vault token create -orphan -policy=default -ttl=10m -format=json | jq -r '.auth.client_token')
ORPHAN_ACCESSOR=$(vault token lookup -format=json "$ORPHAN_TOKEN" | jq -r '.data.accessor')
echo "Orphan accessor: $ORPHAN_ACCESSOR"

# Revoke parent token
vault token revoke "$PARENT_TOKEN"

# Kiểm tra child token — phải thất bại (đã bị cascade revoke)
vault token lookup "$CHILD_TOKEN" 2>&1
# Error: ... token not found

# Kiểm tra orphan token — phải thành công
vault token lookup "$ORPHAN_TOKEN"
# orphan = true, token còn sống

export ORPHAN_ACCESSOR
```

### Bước 4 — Token store role sinh batch token

```bash
# Tạo token store role
vault write auth/token/roles/my-batch-role \
  token_type=batch \
  token_ttl=15m \
  allowed_policies=default

# Tạo token từ role
ROLE_BATCH_TOKEN=$(vault token create -role=my-batch-role -format=json | jq -r '.auth.client_token')
echo "Role batch token: $ROLE_BATCH_TOKEN"
# Prefix phải là hvb.

export ROLE_BATCH_TOKEN
```

### Bước 5 — AppRole sinh periodic service token

```bash
# Enable AppRole (bỏ qua lỗi nếu đã enable rồi)
vault auth enable approle 2>/dev/null || true

# Tạo AppRole role
vault write auth/approle/role/my-daemon \
  token_type=service \
  token_period=2m \
  token_policies=default

# Lấy role_id
ROLE_ID=$(vault read -format=json auth/approle/role/my-daemon/role-id | jq -r '.data.role_id')

# Tạo secret_id
SECRET_ID=$(vault write -format=json -f auth/approle/role/my-daemon/secret-id | jq -r '.data.secret_id')

# Login và lấy token
APPROLE_TOKEN=$(vault write -format=json auth/approle/login \
  role_id="$ROLE_ID" \
  secret_id="$SECRET_ID" | jq -r '.auth.client_token')

# Lưu accessor
APPROLE_ACCESSOR=$(vault token lookup -format=json "$APPROLE_TOKEN" | jq -r '.data.accessor')
echo "AppRole accessor: $APPROLE_ACCESSOR"

# Kiểm tra type=service, period=2m, expire_time trống
vault token lookup -format=json "$APPROLE_TOKEN" | jq '.data | {type, period, expire_time, orphan}'
# type="service", period="2m", expire_time="" (hoặc n/a), orphan=true

export APPROLE_ACCESSOR
```

## Export tất cả biến để chạy verify

```bash
bash verify.sh
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
