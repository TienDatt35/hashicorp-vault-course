---
title: "Thực hành workflow: authenticate, token lookup và revoke"
estMinutes: 20
---

# Thực hành workflow: authenticate, token lookup và revoke

## Mục tiêu

Bạn sẽ thực hành toàn bộ workflow end-to-end của Vault: từ bật auth method, tạo
user, authenticate để nhận token, kiểm tra thông tin token, đọc secret, cho đến
revoke token và xác nhận rằng token đã bị vô hiệu hóa.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs`.

## Nhiệm vụ của bạn

### Bước 1 — Kiểm tra Vault dev server

Chạy lệnh kiểm tra trạng thái Vault và xác nhận server đang chạy ở chế độ dev
(Initialized: true, Sealed: false).

### Bước 2 — Bật auth method userpass

Enable auth method `userpass` trên Vault. Nếu đã enable rồi thì không cần
enable lại.

### Bước 3 — Tạo user alice

Tạo user với username `alice`, password `alice-password`, và gán policy
`default`.

### Bước 4 — Login bằng alice và lưu token

Login vào Vault bằng alice. Lưu giá trị token nhận được vào biến shell
`ALICE_TOKEN` để dùng cho các bước tiếp theo.

> Gợi ý: thêm flag `-format=json` vào lệnh login để lấy output dạng JSON,
> sau đó dùng `jq` để parse token ra.

### Bước 5 — Xem chi tiết token của alice

Dùng `ALICE_TOKEN` để xem thông tin chi tiết của token đó: TTL còn lại,
danh sách policies đang áp dụng, và accessor.

### Bước 6 — Kiểm tra capabilities tại một path

Kiểm tra những capabilities nào token của alice có tại path
`secret/data/myapp/config`.

> Kết quả kỳ vọng: `deny` — alice hiện chỉ có policy `default`, vốn không
> cấp quyền trên path này. Bước tiếp theo sẽ khắc phục điều đó.

### Bước 7 — Tạo policy và cấp quyền cho alice

Tạo một policy tên `myapp-reader` cho phép `read` và `list` trên path
`secret/data/myapp/config`. Sau đó cập nhật user alice để gán thêm policy
này.

Cuối bước, login lại bằng alice để lấy token mới (token cũ chưa có policy
mới), lưu vào biến `ALICE_TOKEN`.

> Gợi ý: `vault policy write <tên> <file>` hoặc dùng heredoc để truyền nội
> dung HCL trực tiếp. Xem thêm: `vault write auth/userpass/users/alice policies=...`

### Bước 8 — Ghi và đọc secret

Dùng root token để ghi secret vào `secret/myapp/config` với giá trị
`env=production`. Sau đó dùng `ALICE_TOKEN` để đọc lại secret đó và xác nhận
dữ liệu trả về đúng.

> Lưu ý: `secret/` là KV v2 mount mặc định trong Vault dev mode — bạn không
> cần enable riêng.

### Bước 9 — Revoke token và xác nhận bị từ chối

Dùng root token để revoke `ALICE_TOKEN`. Sau đó thử dùng `ALICE_TOKEN` để
thực hiện bất kỳ lệnh nào — bạn phải nhận lỗi "bad token" hoặc "permission
denied".

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với
> phần giải đáp.

---

## Khám phá thêm — UI và HTTP API

Hai bước dưới đây không bắt buộc và không được kiểm tra bởi `verify.sh`.
Mục tiêu là để bạn tận mắt thấy rằng CLI, UI và HTTP API đều là cách khác nhau
để gọi đến cùng một Vault.

### Khám phá A — Vault UI

1. Mở Vault UI trong trình duyệt. Trong Codespace, nhấn vào tab **Ports** ở
   thanh dưới VS Code và mở port `8200` bằng nút "Open in Browser". URL sẽ có
   dạng `https://<codespace-name>-8200.app.github.dev`.

2. Đăng nhập bằng **Token method**, nhập `root`.

3. Điều hướng đến **Secret Engines → secret → myapp/config** để xem secret bạn
   đã ghi ở bước 8. Nhấn vào version history để thấy Vault lưu lịch sử.

4. Vào **Access → Auth Methods** để thấy `userpass/` đang được enable. Vào
   **Policies** để xem nội dung policy `myapp-reader` bạn đã tạo.

5. Vào **Access → Entities** và xem thông tin token/entity của alice.

> Mỗi thao tác bạn làm trên UI thực chất là một HTTP request đến
> `/v1/...` — bật DevTools của trình duyệt (F12 → Network) để tận mắt thấy
> các call API phía sau.

### Khám phá B — HTTP API bằng curl

Chạy các lệnh dưới đây trong terminal. So sánh output với lệnh CLI tương đương.

**1. Kiểm tra trạng thái Vault (không cần token):**

```bash
curl -s $VAULT_ADDR/v1/sys/health | jq .
# So sánh: vault status
```

**2. Đọc secret bằng API (dùng root token):**

```bash
curl -s \
  -H "X-Vault-Token: root" \
  $VAULT_ADDR/v1/secret/data/myapp/config | jq .data.data
# So sánh: vault kv get secret/myapp/config
```

**3. Lookup token của alice (tạo lại token trước nếu cần):**

```bash
# Lấy token mới của alice
ALICE_TOKEN=$(vault login \
  -method=userpass -format=json \
  username=alice password=alice-password \
  | jq -r '.auth.client_token')

# Gọi API để lookup token đó
curl -s \
  -H "X-Vault-Token: root" \
  --request POST \
  --data "{\"token\": \"$ALICE_TOKEN\"}" \
  $VAULT_ADDR/v1/auth/token/lookup | jq '{policies: .data.policies, ttl: .data.ttl}'
# So sánh: vault token lookup "$ALICE_TOKEN"
```

**4. Kiểm tra capabilities qua API:**

```bash
curl -s \
  -H "X-Vault-Token: root" \
  --request POST \
  --data "{\"token\": \"$ALICE_TOKEN\", \"path\": \"secret/data/myapp/config\"}" \
  $VAULT_ADDR/v1/sys/capabilities | jq .
# So sánh: vault token capabilities "$ALICE_TOKEN" secret/data/myapp/config
```

> Mỗi lệnh `vault ...` thực chất là wrapper gọi đúng endpoint `/v1/...` này.
> Khi viết ứng dụng tích hợp Vault, bạn sẽ dùng HTTP API hoặc SDK thay vì CLI.

---

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
