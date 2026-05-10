---
title: Đáp án mẫu — Thực hành Vault Token
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này khai thác Vault dev server (token root, địa chỉ `http://127.0.0.1:8200`) để:

1. Quan sát metadata của token gốc.
2. Tạo service token — loại token phổ biến nhất, lưu storage, có thể renew.
3. Tạo batch token — không lưu storage, không thể renew, dùng cho volume cao.
4. Tạo token có giới hạn số lần dùng — Vault tự revoke sau khi đạt giới hạn.

Tất cả các thao tác này đều thông qua `vault token` CLI và sử dụng token auth method (luôn bật tại `/auth/token`).

## Các lệnh

```bash
# Bước 1 — Kiểm tra token hiện tại (root token)
vault token lookup

# Quan sát output:
# type = service
# policies = [root]
# num_uses = 0 (không giới hạn)
# orphan = true (root token là orphan theo thiết kế)
# renewable = false (root token không renew được)

# Bước 2 — Tạo service token với TTL 1 giờ
SERVICE_TOKEN=$(vault token create -ttl=1h -policy=default -field=token)
echo "Service token: $SERVICE_TOKEN"

# Xác nhận prefix hvs. (hoặc s. với Vault < 1.10)
echo "$SERVICE_TOKEN" | grep -E '^hvs\.|^s\.'

# Bước 3 — Dùng service token để tra cứu chính nó
VAULT_TOKEN=$SERVICE_TOKEN vault token lookup

# Trả lại root token
export VAULT_TOKEN=root

# Bước 4 — Tạo batch token và thử gia hạn
BATCH_TOKEN=$(vault token create -type=batch -ttl=1h -policy=default -field=token)
echo "Batch token: $BATCH_TOKEN"

# Xác nhận prefix hvb. (hoặc b. với Vault < 1.10)
echo "$BATCH_TOKEN" | grep -E '^hvb\.|^b\.'

# Thử renew batch token — lệnh này sẽ thất bại (đây là hành vi mong đợi)
vault token renew "$BATCH_TOKEN" || echo "Như kỳ vọng: batch token không thể renew"

# Bước 5 — Tạo token với use-limit=3
USE_LIMIT_TOKEN=$(vault token create -use-limit=3 -ttl=1h -policy=default -field=token)
echo "Use-limit token: $USE_LIMIT_TOKEN"

# Dùng lần 1
VAULT_TOKEN=$USE_LIMIT_TOKEN vault token lookup >/dev/null
echo "Dùng lần 1 xong"

# Dùng lần 2
VAULT_TOKEN=$USE_LIMIT_TOKEN vault token lookup >/dev/null
echo "Dùng lần 2 xong"

# Dùng lần 3 — đây là lần cuối cùng
VAULT_TOKEN=$USE_LIMIT_TOKEN vault token lookup >/dev/null
echo "Dùng lần 3 xong — token bị revoke ngay sau lần này"

# Kiểm tra xem token đã bị revoke chưa
# Lần gọi này sẽ thất bại vì token đã bị revoke
VAULT_TOKEN=$USE_LIMIT_TOKEN vault token lookup 2>&1 || echo "Như kỳ vọng: token đã bị revoke sau 3 lần dùng"

# Trả lại root token
export VAULT_TOKEN=root
```

## Ghi chú kỹ thuật

- `-field=token` trong lệnh `vault token create` giúp lấy ra chỉ chuỗi token (không kèm metadata), tiện để gán vào biến shell.
- Khi thử renew batch token, Vault trả về lỗi với nội dung tương tự `batch tokens cannot be renewed`. Đây là thiết kế có chủ đích.
- Sau lần dùng thứ 3, token với `use-limit=3` bị revoke ngay lập tức. Lần gọi thứ 4 sẽ nhận `permission denied` hoặc `bad token`.
- Root token (`root`) mặc định trong dev server có `orphan = true` và `renewable = false` — đây là đặc điểm riêng của root token.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
