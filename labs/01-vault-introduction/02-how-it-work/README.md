---
title: Khám phá Vault qua CLI, UI và HTTP API
estMinutes: 20
---

# Khám phá Vault qua CLI, UI và HTTP API

## Mục tiêu

Bạn sẽ tương tác với Vault theo ba cách: **CLI** (lệnh `vault`), **UI** (trình
duyệt web), và **HTTP API** (curl). Ba cách này đều gọi vào cùng một Vault —
hiểu sự tương đương giữa chúng giúp bạn linh hoạt khi tích hợp Vault vào hệ
thống thực.

## Yêu cầu

- Vault dev server đã chạy sẵn ở `http://127.0.0.1:8200` với root token `root`.
- Bạn đã hoàn thành lab 1 — secret `kv/app/db` phải tồn tại.
- `jq` đã được cài sẵn trong Codespace.

## Nhiệm vụ của bạn

### Bước 1 — Kiểm tra Vault dev server

```bash
vault status
```

Xác nhận `Sealed: false`.

### Bước 2 — Xem thông tin token hiện tại (CLI)

Xem thông tin chi tiết của token đang dùng:

```bash
vault token lookup
```

Quan sát và ghi nhận các trường: `id`, `policies`, `ttl`, `type`.
Root token có `ttl = 0` (không hết hạn) và `policies = [root]`.

### Bước 3 — Kiểm tra token capabilities (CLI)

Kiểm tra xem token hiện tại có quyền gì trên path `kv/data/app/db`:

```bash
vault token capabilities kv/data/app/db
```

Root token phải trả về `root` — nghĩa là có toàn quyền trên mọi path.

Thử thêm một path khác, ví dụ `sys/health`, để thấy kết quả luôn là `root`
với root token.

### Bước 4 — Khám phá Vault UI

1. Trong Codespace, mở tab **Ports** ở thanh dưới VS Code và chọn **Open in
   Browser** tại port `8200`.

2. Đăng nhập bằng **Token** method, nhập `root`.

3. Điều hướng và ghi nhận những mục sau:
   - **Secrets Engines**: liệt kê các engine đang bật, trong đó có `kv/` bạn
     đã bật ở lab 1.
   - **kv → app/db**: xem secret và version history.
   - **Access → Auth Methods**: thấy `token/` luôn có mặt.
   - **Access → Policies**: xem nội dung policy `root` và `default`.

4. Bật DevTools trình duyệt (F12 → Network), sau đó nhấn vào bất kỳ thông
   tin nào trên UI. Quan sát các HTTP request dạng `GET /v1/...` hoặc
   `LIST /v1/...` — đây chính là API mà CLI cũng đang gọi.

### Bước 5 — Truy vấn Vault qua HTTP API (curl)

Thực hiện các thao tác tương đương bước 2-3 nhưng qua HTTP API.

**Kiểm tra trạng thái (không cần token):**

```bash
curl -s $VAULT_ADDR/v1/sys/health | jq '{initialized, sealed, standby}'
```

**Lookup token hiện tại qua API:**

```bash
curl -s \
  -H "X-Vault-Token: root" \
  --request POST \
  --data '{"token": "root"}' \
  $VAULT_ADDR/v1/auth/token/lookup | jq '{policies: .data.policies, ttl: .data.ttl, type: .data.type}'
```

**Đọc secret kv/app/db qua API:**

```bash
curl -s \
  -H "X-Vault-Token: root" \
  $VAULT_ADDR/v1/kv/data/app/db | jq .data.data
```

**Kiểm tra capabilities qua API:**

```bash
curl -s \
  -H "X-Vault-Token: root" \
  --request POST \
  --data '{"token": "root", "path": "kv/data/app/db"}' \
  $VAULT_ADDR/v1/sys/capabilities | jq .
```

### Bước 6 — So sánh CLI và API

Chạy cặp lệnh sau và so sánh output của chúng:

```bash
# Qua CLI
vault kv get -format=json kv/app/db | jq .data.data

# Qua API (cùng kết quả)
curl -s -H "X-Vault-Token: root" $VAULT_ADDR/v1/kv/data/app/db | jq .data.data
```

Hai output phải trả về cùng dữ liệu — CLI chỉ là wrapper gọi HTTP API.

> Gợi ý: nếu bí ở bất kỳ bước nào, hãy mở `solution.md` để đối chiếu.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
