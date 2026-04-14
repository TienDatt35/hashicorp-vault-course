---
title: Thực hành tạo và kiểm tra Vault Policies
estMinutes: 20
---

# Thực hành tạo và kiểm tra Vault Policies

## Mục tiêu

Thực hành viết policy HCL, đẩy policy lên Vault, tạo token với nhiều policies, và xác minh cơ chế implicit deny, explicit deny cùng additive permissions hoạt động đúng.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã
  được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR` và `VAULT_TOKEN` đã được đặt sẵn.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/04-vault-policy/01-policy-introduction/`.

## Nhiệm vụ của bạn

### Bước 1 — Tạo policy "dev-readonly"

Tạo file `dev-readonly.hcl` với các rules sau:
- Cho phép `read` và `list` trên `secret/data/dev/*`
- Cho phép `list` trên `secret/metadata/dev/*`

Sau đó đẩy policy lên Vault bằng lệnh `vault policy write`.

### Bước 2 — Tạo policy "ops-admin"

Tạo file `ops-admin.hcl` với các rules sau:
- Cho phép `create`, `read`, `update`, `delete`, `list` trên `secret/data/ops/*`
- Explicit deny trên `secret/data/ops/prod-password`

Sau đó đẩy policy lên Vault.

### Bước 3 — Tạo token với nhiều policies và kiểm tra capabilities

Tạo token có cả hai policies `dev-readonly` và `ops-admin`. Dùng lệnh `vault token capabilities` để kiểm tra quyền của token đó trên các paths sau:
- `secret/data/dev/app` — bạn kỳ vọng capabilities gì?
- `secret/data/ops/prod-password` — kỳ vọng gì khi có explicit deny?

### Bước 4 — Đọc root policy và default policy

Dùng lệnh `vault policy read` để xem nội dung của cả hai built-in policies: `root` và `default`. Quan sát sự khác biệt về quyền hạn.

### Bước 5 — Liệt kê tất cả policies

Dùng lệnh `vault policy list` để xem tất cả policies đang tồn tại trong Vault. Xác nhận rằng cả `dev-readonly` và `ops-admin` đều có trong danh sách.

> Gợi ý: hãy tự suy nghĩ và thử trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
