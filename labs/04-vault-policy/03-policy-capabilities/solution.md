---
title: Đáp án mẫu — Capabilities trong Vault Policy
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này minh họa ba hành vi quan trọng của capabilities trong Vault:

1. **Wildcard `*` không cover path gốc** — `secret/data/apps/webapp/*` không match `secret/data/apps/webapp`.
2. **`list` trên KV v2 phải dùng `metadata/` path** — `vault kv list` gửi request tới `metadata/`, không phải `data/`.
3. **`deny` override tuyệt đối** — kể cả khi policy khác cấp `read` cho toàn bộ namespace, `deny` ở path cụ thể vẫn thắng.

## Các lệnh

```bash
# Bước 1 — Tạo secrets test
vault kv put secret/apps/webapp/api url=http://api:8080
vault kv put secret/apps/webapp/db host=db:5432
vault kv put secret/apps/webapp/super-secret password=P@ssw0rd

# Bước 2 — Tạo policy webapp-wildcard (chỉ data/, thiếu metadata/)
cat > /tmp/webapp-wildcard.hcl << 'EOF'
path "secret/data/apps/webapp/*" {
  capabilities = ["read"]
}
EOF

vault policy write webapp-wildcard /tmp/webapp-wildcard.hcl

# Tạo token test với policy webapp-wildcard
WILDCARD_TOKEN=$(vault token create -policy=webapp-wildcard -format=json | jq -r '.auth.client_token')

# Thử đọc — thành công (path có sub-path sau webapp/)
VAULT_TOKEN=$WILDCARD_TOKEN vault kv get secret/apps/webapp/api

# Thử list — thất bại 403 vì thiếu rule cho metadata/
VAULT_TOKEN=$WILDCARD_TOKEN vault kv list secret/apps/webapp/ || echo "Kết quả dự kiến: 403 permission denied"

# Bước 3 — Tạo policy webapp-full (thêm metadata/ để list hoạt động)
cat > /tmp/webapp-full.hcl << 'EOF'
path "secret/data/apps/webapp/*" {
  capabilities = ["read"]
}

path "secret/metadata/apps/webapp/*" {
  capabilities = ["list"]
}
EOF

vault policy write webapp-full /tmp/webapp-full.hcl

# Tạo token test mới với policy webapp-full
FULL_TOKEN=$(vault token create -policy=webapp-full -format=json | jq -r '.auth.client_token')

# Thử list — thành công vì đã có rule metadata/
VAULT_TOKEN=$FULL_TOKEN vault kv list secret/apps/webapp/

# Bước 4 — Tạo policy webapp-deny-secret (deny path cụ thể)
cat > /tmp/webapp-deny-secret.hcl << 'EOF'
path "secret/data/apps/webapp/*" {
  capabilities = ["read"]
}

path "secret/data/apps/webapp/super-secret" {
  capabilities = ["deny"]
}
EOF

vault policy write webapp-deny-secret /tmp/webapp-deny-secret.hcl

# Tạo token test với policy webapp-deny-secret
DENY_TOKEN=$(vault token create -policy=webapp-deny-secret -format=json | jq -r '.auth.client_token')

# Đọc api — thành công
VAULT_TOKEN=$DENY_TOKEN vault kv get secret/apps/webapp/api

# Đọc super-secret — thất bại vì deny
VAULT_TOKEN=$DENY_TOKEN vault kv get secret/apps/webapp/super-secret || echo "Kết quả dự kiến: 403 permission denied"

# Bước 5 — Verify capabilities bằng CLI (dùng root token để check token khác)
# Hiển thị capabilities của DENY_TOKEN tại hai path
vault token capabilities "$DENY_TOKEN" secret/data/apps/webapp/api
# Output dự kiến: [read]

vault token capabilities "$DENY_TOKEN" secret/data/apps/webapp/super-secret
# Output dự kiến: [deny]
```

## Giải thích kết quả Bước 5

Lệnh `vault token capabilities` cho thấy:

- Tại `secret/data/apps/webapp/api`: capabilities là `[read]` — rule `webapp/*` áp dụng.
- Tại `secret/data/apps/webapp/super-secret`: capabilities là `[deny]` — rule cụ thể hơn (exact sub-path) áp dụng và override rule wildcard.

Đây minh họa cả hai nguyên tắc: (1) rule cụ thể hơn được ưu tiên hơn wildcard, và (2) `deny` override tuyệt đối mọi capability khác.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
