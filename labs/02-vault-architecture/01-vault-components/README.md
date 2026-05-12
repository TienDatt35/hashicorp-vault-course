---
title: Khám phá kiến trúc Vault — thành phần và path-based routing
estMinutes: 20
---

# Khám phá kiến trúc Vault — thành phần và path-based routing

## Mục tiêu

Bạn sẽ tương tác trực tiếp với các thành phần cốt lõi của Vault thông qua CLI
và API để hiểu cách chúng hoạt động cùng nhau: Storage Backend, Secrets Engine,
Auth Method, System Backend (`sys/`), và path-based routing.

## Yêu cầu

- Vault dev server đã chạy sẵn tại `http://127.0.0.1:8200` với root token `root`.
- Bạn đã đọc bài lý thuyết "Kiến trúc Vault và Path-based Routing" và "Các thành
  phần cốt lõi của Vault".

## Nhiệm vụ của bạn

### Bước 1 — Kiểm tra Vault dev server và Storage Backend

```bash
vault status
```

Quan sát các trường:
- `Storage Type`: dev mode dùng `inmem` — dữ liệu không bền vững qua restart.
- `Seal Type`: `shamir` (dù dev mode tự unseal).
- `Initialized` và `Sealed`.

### Bước 2 — Khám phá Secrets Engine mặc định

Liệt kê tất cả secrets engine đang được mount:

```bash
vault secrets list
vault secrets list -detailed
```

Ghi nhận các engine mặc định trong dev mode và path của từng engine. Đặc biệt
chú ý `cubbyhole/`, `identity/`, `secret/`, `sys/`.

Xem thông tin chi tiết của một engine qua System Backend:

```bash
vault read sys/mounts/secret
```

### Bước 3 — Khám phá Auth Methods mặc định

Liệt kê tất cả auth method đang được enable:

```bash
vault auth list
vault auth list -detailed
```

Xác nhận `token/` luôn có mặt và không thể bị disable. Đây là auth method
duy nhất Vault enable sẵn.

### Bước 4 — Khám phá System Backend `sys/`

Mọi thao tác quản lý Vault đều đi qua `sys/`. Đọc trực tiếp:

```bash
# Xem tất cả mounts qua sys/ (tương đương vault secrets list)
vault read sys/mounts

# Xem tất cả auth methods qua sys/ (tương đương vault auth list)
vault read sys/auth
```

So sánh output của `vault secrets list` với `vault read sys/mounts` — chúng
trả về cùng dữ liệu. CLI chỉ là wrapper gọi `sys/` API phía sau.

### Bước 5 — Enable Secrets Engine tại custom path

Enable KV v2 tại path tùy chỉnh `app/` (thay vì path mặc định `kv/`):

```bash
vault secrets enable -version=2 -path=app kv
```

Sau đó enable thêm một instance KV khác tại path `config/`:

```bash
vault secrets enable -version=2 -path=config kv
```

Xác nhận cả hai path xuất hiện trong danh sách:

```bash
vault secrets list
```

Đây là minh họa cho custom path: cùng loại engine (`kv`) chạy tại hai path
độc lập.

### Bước 6 — Kiểm chứng path-based routing

Ghi secret vào từng path và xác nhận dữ liệu được routed đúng:

```bash
# Ghi secret vào engine tại app/
vault kv put app/database password=db-secret

# Ghi secret vào engine tại config/
vault kv put config/feature-flags debug=true

# Đọc lại — mỗi path là một engine độc lập
vault kv get app/database
vault kv get config/feature-flags
```

### Bước 7 — Enable Auth Method

Enable auth method `userpass` và tạo một user:

```bash
vault auth enable userpass
vault write auth/userpass/users/student password=student-pass policies=default
```

Xác nhận userpass xuất hiện tại `auth/userpass/`:

```bash
vault auth list
```

### Bước 8 — Kiểm tra Reserved Paths

Thử mount engine tại các reserved path — những lệnh này phải thất bại:

```bash
# Không thể mount tại sys/ vì là reserved
vault secrets enable -path=sys kv

# Không thể mount tại identity/ vì là reserved
vault secrets enable -path=identity kv
```

Vault sẽ báo lỗi cho cả hai lệnh — đây là hành vi đúng, reserved path không
thể bị ghi đè.

> Gợi ý: nếu bí ở bất kỳ bước nào, hãy mở `solution.md` để đối chiếu.

## Tiêu chí thành công

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
