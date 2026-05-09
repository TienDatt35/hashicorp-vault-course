---
title: Đáp án mẫu — Vault Identity Groups
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này minh họa hai loại group trong Vault Identity system:

- **Internal Group** (`dev-team`): membership được quản lý thủ công trong Vault bằng `member_entity_ids`. Đây là cách đơn giản nhất để gán policy cho nhiều entities cùng lúc mà không cần IdP bên ngoài.
- **External Group** (`ops-team`): membership đến từ auth method bên ngoài thông qua Group Alias. Khi alice đăng nhập qua userpass và alias `alice` khớp với group alias `alice` của `ops-team`, Vault tự động tính alice là member của external group đó.

Cả hai đều minh họa công thức: `token = union(alias policies + entity policies + group policies)`.

## Các lệnh

```bash
# ============================================================
# Bước 1 — Tạo policies
# ============================================================

# Policy dev: đọc secret tại secret/data/dev
vault policy write dev - <<EOF
path "secret/data/dev" {
  capabilities = ["read"]
}
EOF

# Policy ops: đọc secret tại secret/data/ops
vault policy write ops - <<EOF
path "secret/data/ops" {
  capabilities = ["read"]
}
EOF

# ============================================================
# Bước 2 — Enable userpass và tạo users
# ============================================================

vault auth enable userpass

vault write auth/userpass/users/alice password="training"
vault write auth/userpass/users/bob password="training"

# ============================================================
# Bước 3 — Tạo entities và aliases
# ============================================================

# Tạo entity alice-entity
ALICE_ENTITY_ID=$(vault write -format=json identity/entity \
  name="alice-entity" \
  | jq -r '.data.id')

echo "alice-entity ID: $ALICE_ENTITY_ID"

# Tạo entity bob-entity
BOB_ENTITY_ID=$(vault write -format=json identity/entity \
  name="bob-entity" \
  | jq -r '.data.id')

echo "bob-entity ID: $BOB_ENTITY_ID"

# Lấy accessor của userpass
USERPASS_ACCESSOR=$(vault auth list -format=json | jq -r '.["userpass/"].accessor')
echo "userpass accessor: $USERPASS_ACCESSOR"

# Tạo alias alice → alice-entity
vault write identity/entity-alias \
  name="alice" \
  canonical_id="$ALICE_ENTITY_ID" \
  mount_accessor="$USERPASS_ACCESSOR"

# Tạo alias bob → bob-entity
vault write identity/entity-alias \
  name="bob" \
  canonical_id="$BOB_ENTITY_ID" \
  mount_accessor="$USERPASS_ACCESSOR"

# ============================================================
# Bước 4 — Tạo Internal Group dev-team
# ============================================================

vault write identity/group \
  name="dev-team" \
  policies="dev" \
  member_entity_ids="$ALICE_ENTITY_ID,$BOB_ENTITY_ID"

# ============================================================
# Bước 5 — Kiểm tra kế thừa policy từ Internal Group
# ============================================================

# Đăng nhập bằng alice
ALICE_TOKEN=$(vault write -format=json auth/userpass/login/alice \
  password="training" \
  | jq -r '.auth.client_token')

echo "Alice token: $ALICE_TOKEN"

# Kiểm tra capabilities tại secret/data/dev
VAULT_TOKEN="$ALICE_TOKEN" vault token capabilities secret/data/dev
# Kết quả mong đợi: read

# ============================================================
# Bước 6 — Tạo External Group ops-team
# ============================================================

OPS_GROUP_ID=$(vault write -format=json identity/group \
  name="ops-team" \
  type="external" \
  policies="ops" \
  | jq -r '.data.id')

echo "ops-team group ID: $OPS_GROUP_ID"

# ============================================================
# Bước 7 — Lấy accessor của userpass (đã lấy ở bước 3)
# ============================================================

# USERPASS_ACCESSOR đã được lưu ở bước 3
echo "userpass accessor: $USERPASS_ACCESSOR"

# ============================================================
# Bước 8 — Tạo Group Alias cho External Group
# ============================================================

vault write identity/group-alias \
  name="alice" \
  mount_accessor="$USERPASS_ACCESSOR" \
  canonical_id="$OPS_GROUP_ID"

# ============================================================
# Bước 9 — Kiểm tra kế thừa policy từ External Group
# ============================================================

# Đăng nhập lại bằng alice (cần token mới để nhận membership mới)
ALICE_TOKEN_NEW=$(vault write -format=json auth/userpass/login/alice \
  password="training" \
  | jq -r '.auth.client_token')

# Kiểm tra capabilities tại secret/data/ops
VAULT_TOKEN="$ALICE_TOKEN_NEW" vault token capabilities secret/data/ops
# Kết quả mong đợi: read
```

## Giải thích thêm

**Tại sao phải đăng nhập lại ở bước 9?**

Token của alice từ bước 5 được cấp trước khi group alias được tạo ở bước 8. Khi đó, alice chưa được map vào external group `ops-team`. Vault chỉ cập nhật membership của external group khi user đăng nhập mới hoặc renew token. Do đó phải đăng nhập lại để nhận token mới với membership đầy đủ.

**Tại sao External Group dùng `name="alice"` cho group alias?**

Với userpass auth method, Vault dùng username làm identifier khi người dùng đăng nhập. Khi alice đăng nhập, Vault kiểm tra xem có group alias nào có `name="alice"` trên mount userpass không. Nếu có, alice được tính là member của external group tương ứng.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
