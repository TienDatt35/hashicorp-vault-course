---
title: Đáp án mẫu — Chọn Token Phù Hợp — Best Practice
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này áp dụng decision matrix để map từng yêu cầu vận hành sang đúng loại
token. Policy `best-practice-policy` là nền chung; điểm khác biệt nằm ở flag
CLI dùng khi tạo token và metadata kết quả.

- **Periodic token:** flag `-period` thay cho `-ttl` (hoặc dùng cả hai). Vault
  tự hiểu đây là periodic token và không đặt max TTL.
- **Use-limit token:** flag `-use-limit=N` kết hợp với `-ttl`. Vault đếm ngược
  `num_uses` sau mỗi lần dùng.
- **Orphan token:** flag `-orphan` để Vault không gán parent. Hay gặp khi dùng
  non-token auth method — Vault luôn trả về orphan token.
- **Batch token:** flag `-type=batch`. Vault tạo encrypted blob thay vì ghi vào
  storage. Không thể renew — đây là đặc tính thiết kế, không phải lỗi.

## Các lệnh

```bash
# Bước 1 — Tạo policy best-practice-policy
vault policy write best-practice-policy - <<EOF
path "secret/data/app/*" {
  capabilities = ["read"]
}
EOF

# Bước 2 — Tạo periodic token (period=1h, TTL reset vô hạn khi renew đúng hạn)
PERIODIC_TOKEN=$(vault token create \
  -policy=best-practice-policy \
  -period=1h \
  -format=json | jq -r '.auth.client_token')

echo "Periodic token: $PERIODIC_TOKEN"

# Kiểm tra metadata — chú ý trường period và explicit_max_ttl
vault token lookup "$PERIODIC_TOKEN"

# Bước 3 — Tạo use-limit token (chỉ dùng được 3 lần)
USE_LIMIT_TOKEN=$(vault token create \
  -policy=best-practice-policy \
  -use-limit=3 \
  -ttl=1h \
  -format=json | jq -r '.auth.client_token')

echo "Use-limit token: $USE_LIMIT_TOKEN"

# Kiểm tra metadata — chú ý num_uses=3
vault token lookup "$USE_LIMIT_TOKEN"

# Bước 4 — Tạo orphan token (không có parent, không bị revoke theo parent)
ORPHAN_TOKEN=$(vault token create \
  -policy=best-practice-policy \
  -orphan \
  -ttl=1h \
  -format=json | jq -r '.auth.client_token')

echo "Orphan token: $ORPHAN_TOKEN"

# Kiểm tra metadata — chú ý orphan=true
vault token lookup "$ORPHAN_TOKEN"

# Bước 5 — Tạo batch token (stateless, không ghi storage)
BATCH_TOKEN=$(vault token create \
  -policy=best-practice-policy \
  -type=batch \
  -ttl=1h \
  -format=json | jq -r '.auth.client_token')

echo "Batch token: $BATCH_TOKEN"

# Thử renew batch token — phải thất bại với thông báo lỗi
vault token renew "$BATCH_TOKEN" || echo "Xác nhận: batch token không thể renew"
```

## Những điểm cần chú ý khi quan sát output

**Periodic token lookup:**
- `period`: thời gian reset TTL (ví dụ: `3600` giây = 1 giờ)
- `renewable: true`
- `explicit_max_ttl: 0` — không có giới hạn tối đa

**Use-limit token lookup:**
- `num_uses: 3` — số lần dùng còn lại
- Lưu ý: chính lệnh `vault token lookup` cũng tiêu thụ 1 lần dùng, nên sau
  khi lookup, `num_uses` sẽ còn 2

**Orphan token lookup:**
- `orphan: true`
- `path: auth/token/create` — đường tạo token

**Batch token:**
- Token value bắt đầu bằng `hvb.` thay vì `hvs.` (prefix của service token)
- Lệnh renew trả về lỗi: `batch tokens cannot be renewed`

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
