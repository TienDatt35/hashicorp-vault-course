---
title: Đáp án mẫu — Thực hành Token Metadata
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này cho bạn thực hành trực tiếp với vòng đời token. Các khái niệm quan trọng được kiểm chứng bằng tay:

- `display_name` và `meta` giúp phân biệt token trong audit log.
- `explicit_max_ttl` là giới hạn cứng không thể vượt qua dù renew bao nhiêu lần.
- `num_uses` đếm ngược mỗi lần token đó được dùng làm auth token — phải dùng `VAULT_TOKEN=$token vault ...` chứ không phải `vault token lookup $token` (cái sau dùng root, không tiêu thụ use).
- Cascade revocation: token con bị revoke theo cha; orphan token không bị ảnh hưởng.

## Các lệnh

```bash
# Bước 1 — Xem metadata root token
vault token lookup

# Bước 2 — Tạo token với display_name và metadata
LAB_TOKEN=$(vault token create \
  -display-name="lab-user" \
  -metadata="env=lab" \
  -policy=default \
  -format=json | jq -r '.auth.client_token')

# Lưu accessor của token bước 2
export LAB_ACCESSOR=$(vault token lookup -format=json "$LAB_TOKEN" | jq -r '.data.accessor')
echo "LAB_ACCESSOR=$LAB_ACCESSOR"

# Xác nhận display_name và meta đúng
vault token lookup "$LAB_TOKEN"

# Bước 3 — Tạo token với explicit_max_ttl
MAX_TTL_TOKEN=$(vault token create \
  -ttl=2m \
  -explicit-max-ttl=5m \
  -policy=default \
  -format=json | jq -r '.auth.client_token')

# Lưu accessor của token bước 3
export MAX_TTL_ACCESSOR=$(vault token lookup -format=json "$MAX_TTL_TOKEN" | jq -r '.data.accessor')
echo "MAX_TTL_ACCESSOR=$MAX_TTL_ACCESSOR"

# Renew lần 1 — thành công
vault token renew "$MAX_TTL_TOKEN"

# Renew lần 2 đẩy expire_time vượt explicit_max_ttl
# (chờ vài giây để ttl giảm, sau đó renew với ttl lớn hơn phần còn lại đến max)
vault token renew -increment=5m "$MAX_TTL_TOKEN"
# Kết quả dự kiến: lỗi "...would exceed the maximum TTL..."
# hoặc Vault tự cắt ngắn TTL xuống còn phần thời gian còn lại đến explicit_max_ttl

# Bước 4 — Tạo token với use-limit=3
USE_TOKEN=$(vault token create \
  -use-limit=3 \
  -policy=default \
  -format=json | jq -r '.auth.client_token')

# Dùng lần 1, 2, 3 — PHẢI dùng USE_TOKEN làm auth token để tiêu thụ use
# (vault token lookup "$USE_TOKEN" dùng root làm auth → không tiêu thụ use của USE_TOKEN)
VAULT_TOKEN=$USE_TOKEN vault token lookup
VAULT_TOKEN=$USE_TOKEN vault token lookup
VAULT_TOKEN=$USE_TOKEN vault token lookup

# Lần 4 — token đã bị revoke tự động sau 3 lần dùng
VAULT_TOKEN=$USE_TOKEN vault token lookup
# Kết quả dự kiến: Error looking up token: ... permission denied / token not found

# Bước 5 — Orphan token và cascade revocation
# Tạo policy cho parent để parent có quyền tạo child token
# (default policy không có quyền auth/token/create)
vault policy write parent-policy - <<'EOF'
path "auth/token/create" {
  capabilities = ["create", "update"]
}
EOF

PARENT_TOKEN=$(vault token create \
  -policy=parent-policy \
  -ttl=30m \
  -format=json | jq -r '.auth.client_token')

# Tạo child token từ parent (VAULT_TOKEN=parent)
CHILD_TOKEN=$(VAULT_TOKEN="$PARENT_TOKEN" vault token create \
  -policy=default \
  -ttl=30m \
  -format=json | jq -r '.auth.client_token')

# Tạo orphan token (dùng root token, flag -orphan)
ORPHAN_TOKEN=$(vault token create \
  -orphan \
  -policy=default \
  -ttl=30m \
  -format=json | jq -r '.auth.client_token')

# Lưu accessor của orphan token
export ORPHAN_ACCESSOR=$(vault token lookup -format=json "$ORPHAN_TOKEN" | jq -r '.data.accessor')
echo "ORPHAN_ACCESSOR=$ORPHAN_ACCESSOR"

# Revoke parent token (sẽ kéo theo child token)
vault token revoke "$PARENT_TOKEN"

# Kiểm tra child đã bị revoke chưa (phải lỗi)
vault token lookup "$CHILD_TOKEN"
# Kết quả dự kiến: Error ... token not found

# Kiểm tra orphan vẫn sống (phải thành công)
vault token lookup "$ORPHAN_TOKEN"
# Kết quả dự kiến: metadata của orphan token, orphan=true
```

## Xuất biến trước khi chạy verify

Nếu bạn đã chạy xong các lệnh trên trong cùng một terminal session, các biến `LAB_ACCESSOR`, `MAX_TTL_ACCESSOR`, `ORPHAN_ACCESSOR` đã được export. Nếu không, hãy chạy lại phần lưu accessor rồi mới verify:

```bash
sh verify.sh
```

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
