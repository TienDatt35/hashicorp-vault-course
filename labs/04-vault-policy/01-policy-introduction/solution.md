---
title: Đáp án mẫu — Thực hành tạo và kiểm tra Vault Policies
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này minh hoạ ba khái niệm cốt lõi của Vault Policy:

1. **Implicit deny**: Vault từ chối mọi path không có rule khớp — không cần viết "deny" cho từng path muốn chặn.
2. **Explicit deny**: `capabilities = ["deny"]` luôn override mọi quyền khác, dù token có bao nhiêu policies.
3. **Additive permissions**: Token có nhiều policies sẽ có quyền là union của tất cả capabilities từ mọi policies.

## Các lệnh

### Bước 1 — Tạo policy "dev-readonly"

Tạo file `dev-readonly.hcl`:

```hcl
# Policy chỉ cho phép đọc và liệt kê secret trong namespace "dev"
path "secret/data/dev/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/dev/*" {
  capabilities = ["list"]
}
```

Đẩy policy lên Vault:

```bash
vault policy write dev-readonly dev-readonly.hcl
```

Xác nhận policy đã được tạo:

```bash
vault policy read dev-readonly
```

### Bước 2 — Tạo policy "ops-admin"

Tạo file `ops-admin.hcl`:

```hcl
# Policy cho phép quản lý secret trong namespace "ops"
# Ngoại trừ path prod-password bị chặn tuyệt đối
path "secret/data/ops/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Explicit deny — override mọi quyền khác dù token có bao nhiêu policies
path "secret/data/ops/prod-password" {
  capabilities = ["deny"]
}
```

Đẩy policy lên Vault:

```bash
vault policy write ops-admin ops-admin.hcl
```

### Bước 3 — Tạo token với nhiều policies và kiểm tra capabilities

Tạo token có cả hai policies:

```bash
vault token create -policy=dev-readonly -policy=ops-admin
```

Lưu lại giá trị token từ output (trường `token`). Dùng token đó để kiểm tra capabilities:

```bash
# Kiểm tra capabilities trên path dev — kỳ vọng: read, list (từ dev-readonly)
vault token capabilities <giá-trị-token> secret/data/dev/app

# Kiểm tra capabilities trên path ops thông thường — kỳ vọng: create, delete, list, read, update (từ ops-admin)
vault token capabilities <giá-trị-token> secret/data/ops/app

# Kiểm tra capabilities trên path bị deny — kỳ vọng: deny (explicit deny override tất cả)
vault token capabilities <giá-trị-token> secret/data/ops/prod-password
```

Quan sát: dù token có `ops-admin` policy với quyền rộng trên `secret/data/ops/*`, explicit deny trên `secret/data/ops/prod-password` vẫn thắng hoàn toàn.

### Bước 4 — Đọc root policy và default policy

```bash
# Xem nội dung default policy — bao gồm self-lookup, token renew/revoke, cubbyhole
vault policy read default

# Cố đọc root policy — Vault sẽ trả về nội dung trống hoặc thông báo đặc biệt
vault policy read root
```

Quan sát sự khác biệt: `default` policy có nội dung HCL cụ thể với các quyền giới hạn, trong khi `root` policy là trường hợp đặc biệt tương đương với toàn quyền tất cả paths.

### Bước 5 — Liệt kê tất cả policies

```bash
vault policy list
```

Output phải bao gồm: `default`, `root`, `dev-readonly`, `ops-admin`.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
