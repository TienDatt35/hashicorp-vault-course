---
title: Đáp án mẫu — Wildcard và ACL Templating trong Vault Policy
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này minh hoạ ba kỹ thuật viết path linh hoạt trong Vault policy:

1. **Wildcard `+`**: match đúng một path segment, cho phép cùng một policy áp dụng cho nhiều môi trường (`dev`, `prod`, ...) mà không cần viết nhiều rules.
2. **Prefix pattern `db-*`**: match nhóm path có chung prefix tên (không phải thư mục con), hữu ích khi bạn muốn cấp quyền cho nhóm secret có tên theo quy ước đặt tên.
3. **ACL Templating**: dùng biến `{{identity.entity.id}}` để tạo policy động — mọi người dùng dùng chung một policy nhưng chỉ truy cập được vùng dữ liệu của entity mình.

## Các lệnh

```bash
# =========================================================
# Bước 1: Tạo secrets để thực hành
# =========================================================

vault kv put secret/apps/dev/webapp api_key=dev-key
vault kv put secret/apps/prod/webapp api_key=prod-key
vault kv put secret/apps/dev/database host=db:5432
vault kv put secret/apps/dev/db-primary host=primary:5432
vault kv put secret/apps/dev/db-replica host=replica:5432

# =========================================================
# Bước 2: Policy dùng wildcard + (single segment)
# =========================================================

vault policy write env-webapp - <<'EOF'
# Match bất kỳ environment (dev, prod, staging, ...) nhưng chỉ path webapp
path "secret/data/apps/+/webapp" {
  capabilities = ["read"]
}

path "secret/metadata/apps/+/webapp" {
  capabilities = ["list"]
}
EOF

# Tạo token gắn policy env-webapp
ENV_TOKEN=$(vault token create -policy=env-webapp -field=token)

# Xác nhận: đọc được dev/webapp và prod/webapp
VAULT_TOKEN=$ENV_TOKEN vault kv get secret/apps/dev/webapp
VAULT_TOKEN=$ENV_TOKEN vault kv get secret/apps/prod/webapp

# Xác nhận: không đọc được database (policy không có rule khớp)
VAULT_TOKEN=$ENV_TOKEN vault kv get secret/apps/dev/database || echo "Bị từ chối — đúng như mong đợi"

# =========================================================
# Bước 3: Policy dùng prefix pattern db-*
# =========================================================

vault policy write db-prefix - <<'EOF'
# Match mọi secret có tên bắt đầu bằng "db-" trong apps/dev/
# Lưu ý: db-* match "db-primary", "db-replica" — KHÔNG match "database"
path "secret/data/apps/dev/db-*" {
  capabilities = ["read"]
}
EOF

# Tạo token gắn policy db-prefix
DB_TOKEN=$(vault token create -policy=db-prefix -field=token)

# Xác nhận: đọc được db-primary và db-replica
VAULT_TOKEN=$DB_TOKEN vault kv get secret/apps/dev/db-primary
VAULT_TOKEN=$DB_TOKEN vault kv get secret/apps/dev/db-replica

# Xác nhận: không đọc được database (tên không có prefix db-)
VAULT_TOKEN=$DB_TOKEN vault kv get secret/apps/dev/database || echo "Bị từ chối — đúng như mong đợi"

# =========================================================
# Bước 4: ACL Templating với identity.entity.id
# =========================================================

# 4.1: Enable userpass auth method
vault auth enable userpass

# 4.2: Tạo user alice
vault write auth/userpass/users/alice password=training

# 4.3: Tạo entity với metadata
vault write identity/entity \
  name=alice-entity \
  metadata=team=platform

# Lưu entity ID để dùng ở bước sau
ENTITY_ID=$(vault read -field=id identity/entity/name/alice-entity)
echo "Entity ID: $ENTITY_ID"

# 4.4: Lấy mount accessor của userpass và tạo alias
USERPASS_ACCESSOR=$(vault auth list -format=json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['userpass/']['accessor'])")

vault write identity/entity-alias \
  name="alice" \
  canonical_id="$ENTITY_ID" \
  mount_accessor="$USERPASS_ACCESSOR"

# 4.5: Tạo policy per-entity với ACL Templating
vault policy write per-entity - <<'EOF'
path "secret/data/{{identity.entity.id}}/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}
EOF

# 4.6: Gắn policy per-entity vào entity alice-entity
vault write identity/entity/name/alice-entity \
  policies=per-entity

# 4.7: Login bằng alice để lấy token
ALICE_TOKEN=$(vault login -method=userpass -field=token username=alice password=training)
echo "Alice token: $ALICE_TOKEN"

# Xem entity_id trong token
VAULT_TOKEN=$ALICE_TOKEN vault token lookup

# 4.8: Tạo secret tại path của entity
VAULT_TOKEN=$ALICE_TOKEN vault kv put secret/$ENTITY_ID/config env=dev

# 4.9: Đọc lại secret bằng token của alice
VAULT_TOKEN=$ALICE_TOKEN vault kv get secret/$ENTITY_ID/config
```

## Lưu ý quan trọng

- Ở Bước 4, `vault login` sẽ ghi đè `VAULT_TOKEN` trong phiên shell hiện tại. Hãy lưu token root vào biến trước nếu cần dùng lại:
  ```bash
  ROOT_TOKEN=root
  # ... sau khi login bằng alice ...
  export VAULT_TOKEN=$ROOT_TOKEN  # khôi phục root token
  ```

- `python3` được dùng để parse JSON accessor. Nếu không có `python3`, bạn có thể dùng `jq`:
  ```bash
  USERPASS_ACCESSOR=$(vault auth list -format=json | jq -r '.["userpass/"].accessor')
  ```

- Sau khi gán policy vào entity, token của alice nhận policy qua entity — không cần gán policy trực tiếp vào token.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
