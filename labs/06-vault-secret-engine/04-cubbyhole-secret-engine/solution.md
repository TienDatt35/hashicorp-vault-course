---
title: Đáp án mẫu — Thực hành Cubbyhole và Response Wrapping
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này khai thác hai tính chất cốt lõi của Cubbyhole: isolation theo token (mỗi token chỉ đọc được cubbyhole của chính nó) và làm nền tảng cho Response Wrapping (wrapping token là single-use, có TTL ngắn, mang secret đi qua kênh không tin tưởng an toàn). Kết thúc bài, bạn sẽ tự chứng kiến lỗi "wrapping token is not valid" khi cố unwrap lần hai — đây là tamper detection trong thực tế.

---

## Bước 1 — Ghi và đọc secret vào Cubbyhole

```bash
# Ghi secret vào cubbyhole của root token
vault write cubbyhole/lab-note content="day-la-note-cua-toi"

# Đọc lại để xác nhận
vault read cubbyhole/lab-note
```

Lệnh `vault write cubbyhole/...` ghi dữ liệu vào namespace cubbyhole của token hiện tại (`VAULT_TOKEN=root`). Không cần mount hay enable thêm bất cứ thứ gì — cubbyhole luôn sẵn sàng.

---

## Bước 2 — Xác nhận Cubbyhole isolation

```bash
# Tạo token mới với policy default, lưu vào biến
NEW_TOKEN=$(vault token create -policy=default -format=json | \
  jq -r '.auth.client_token')

echo "Token mới: $NEW_TOKEN"

# Thử đọc cubbyhole/lab-note bằng token mới
# Kết quả mong đợi: không có dữ liệu (trả về rỗng, không phải lỗi 403)
VAULT_TOKEN="$NEW_TOKEN" vault read cubbyhole/lab-note
```

Kết quả sẽ là `No value found at cubbyhole/lab-note` — không phải lỗi permission, mà là cubbyhole của token mới hoàn toàn trống. Cubbyhole của mỗi token là không gian riêng biệt, không giao nhau.

---

## Bước 3 — Chuẩn bị secret KV và thực hiện Response Wrapping

```bash
# Ghi secret vào KV v2
vault kv put -mount=secret lab/db-password value="P@ssw0rd-lab-2024"

# Đọc secret với wrap-ttl=120s để nhận wrapping token
WRAP_TOKEN=$(vault read -wrap-ttl=120s -format=json secret/data/lab/db-password | \
  jq -r '.wrap_info.token')

echo "Wrapping token: $WRAP_TOKEN"
```

Flag `-wrap-ttl=120s` báo Vault tạo wrapping token với TTL 120 giây thay vì trả về secret thật. Vault ghi secret vào cubbyhole của wrapping token, rồi trả về token đó. Bạn không thấy giá trị `P@ssw0rd-lab-2024` trong output.

---

## Bước 4 — Kiểm tra creation_path của wrapping token

```bash
# Dùng curl để gọi /sys/wrapping/lookup
curl -s \
  -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$WRAP_TOKEN\"}" \
  "$VAULT_ADDR/v1/sys/wrapping/lookup" | \
  jq -r '"creation_path: \(.data.creation_path)"'
```

Kết quả mong đợi:

```
creation_path: secret/data/lab/db-password
```

Nếu `creation_path` không khớp với path mong đợi, đây là dấu hiệu wrapping token có thể đã bị tráo đổi. Trong thực tế, bước này phải thực hiện trước khi unwrap.

---

## Bước 5 — Unwrap lấy secret thật

```bash
# Unwrap để lấy secret thật
vault unwrap "$WRAP_TOKEN"
```

Output sẽ hiển thị dữ liệu thật:

```
Key      Value
---      -----
value    P@ssw0rd-lab-2024
```

Sau lệnh này, wrapping token bị revoke ngay lập tức.

---

## Bước 6 — Thử unwrap lần hai (single-use behavior)

```bash
# Thử dùng lại wrapping token đã unwrap
vault unwrap "$WRAP_TOKEN"
```

Kết quả mong đợi:

```
Error unwrapping: Error making API request.
URL: PUT http://127.0.0.1:8200/v1/sys/wrapping/unwrap
Code: 400. Errors:
* wrapping token is not valid or does not exist
```

Đây là hành vi single-use: sau lần unwrap đầu tiên, wrapping token bị revoke. Nếu bạn nhận lỗi này ngay lần unwrap đầu tiên (không phải lần hai), đó là dấu hiệu ai đó đã unwrap trước bạn — cần phát cảnh báo security incident ngay.

---

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
