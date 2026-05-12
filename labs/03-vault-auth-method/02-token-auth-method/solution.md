---
title: Xác thực vào Vault bằng Token — Đáp án mẫu
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Token không chỉ là "chìa khóa để vào Vault" — nó còn mang theo danh sách
policy xác định bạn được làm gì. Khi tạo token với policy giới hạn, mọi thao
tác ngoài phạm vi đó đều bị Vault từ chối ngay lập tức với lỗi
`permission denied`. Đây là cơ chế authorization cốt lõi của Vault.

## Các lệnh

```bash
# ============================================================
# Phần 1 — Dùng token để xác thực
# ============================================================

# Bước 1 — Xem thông tin token hiện tại
vault token lookup
# Các trường quan trọng:
#   id          — giá trị token thực (root)
#   policies    — [root]
#   ttl         — 0 (root token không hết hạn)
#   type        — service
#   accessor    — ID tham chiếu token

# Bước 2 — Token không hợp lệ
VAULT_TOKEN=invalid vault token lookup
# Kết quả: Error ... Code: 403. Errors: * permission denied

# Bước 3 — Gọi API với X-Vault-Token
export VAULT_TOKEN=root
curl -s \
  -H "X-Vault-Token: root" \
  http://127.0.0.1:8200/v1/auth/token/lookup-self \
  | jq '{policies: .data.policies, type: .data.type}'
# Kết quả: {"policies": ["root"], "type": "service"}

# Bước 4 — Gọi không có token
curl -s http://127.0.0.1:8200/v1/auth/token/lookup-self
# Response: {"errors":["missing client token"]}
# HTTP status: 403


# ============================================================
# Phần 2 — Cấp quyền qua policy và kiểm tra giới hạn
# ============================================================

# Bước 5 — Tạo secret (dùng root token)
export VAULT_TOKEN=root
vault kv put secret/team-a/config env=production region=us-east-1

# Đọc lại để xác nhận
vault kv get secret/team-a/config

# Bước 6 — Tạo policy chỉ cho phép đọc tại secret/data/team-a/*
vault policy write team-a-readonly - <<'EOF'
path "secret/data/team-a/*" {
  capabilities = ["read"]
}
EOF

# Xác nhận policy đã tạo
vault policy read team-a-readonly

# Bước 7 — Tạo token với policy team-a-readonly
TEAM_TOKEN=$(vault token create \
  -policy=team-a-readonly \
  -ttl=1h \
  -field=token)
echo "Team token: $TEAM_TOKEN"

# Xác nhận token có đúng policy
vault token lookup "$TEAM_TOKEN"
# Trường policies phải là: [default team-a-readonly]


# Bước 8 — Hành động được phép: đọc secret
VAULT_TOKEN="$TEAM_TOKEN" vault kv get secret/team-a/config
# Kết quả thành công — thấy được env=production, region=us-east-1


# Bước 9 — Hành động bị cấm

# 9a — Ghi vào secret (không có capabilities "create" hay "update")
VAULT_TOKEN="$TEAM_TOKEN" vault kv put secret/team-a/config env=staging
# Kết quả: Error ... Code: 403. Errors: * 1 error occurred: permission denied

# 9b — Đọc secret ở path khác (không khớp policy pattern)
VAULT_TOKEN="$TEAM_TOKEN" vault kv get secret/other/config
# Kết quả: Error ... Code: 403. Errors: * 1 error occurred: permission denied

# 9c — Xem danh sách auth methods (không có quyền sys/)
VAULT_TOKEN="$TEAM_TOKEN" vault auth list
# Kết quả: Error ... Code: 403. Errors: * 1 error occurred: permission denied


# Bước 10 — Thu hồi token
export VAULT_TOKEN=root
vault token revoke "$TEAM_TOKEN"

# Xác nhận token không còn dùng được
VAULT_TOKEN="$TEAM_TOKEN" vault kv get secret/team-a/config
# Kết quả: Error ... Code: 403. Errors: * permission denied (bad token)
```

## Giải thích policy

```hcl
path "secret/data/team-a/*" {
  capabilities = ["read"]
}
```

- `secret/data/team-a/*` — glob `*` khớp với mọi sub-path bên dưới `team-a/`
- `capabilities = ["read"]` — chỉ cho phép đọc, không có `create`, `update`,
  `delete`, `list`
- Mọi path không được liệt kê rõ trong policy đều mặc định bị từ chối

Lưu ý: KV v2 lưu secret tại `secret/data/<path>` dù bạn gõ lệnh
`vault kv get secret/<path>` — Vault CLI tự thêm `/data/` vào path khi làm
việc với KV v2.

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
