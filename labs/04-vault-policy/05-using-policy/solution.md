# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này thực hành toàn bộ vòng đời sử dụng policy: viết HCL, ghi policy vào Vault, tạo token gắn policy, kiểm tra metadata bằng `lookup`, rồi thực sự đăng nhập và thử cả path được phép lẫn path bị từ chối. Quy trình này là cách chuẩn để xác minh policy trước khi đưa vào production.

Điểm then chốt cần nhớ:
- KV v2 dùng `secret/data/...` cho đọc/ghi, `secret/metadata/...` cho list.
- `default` policy tự động gắn vào mọi token — `vault token lookup` sẽ luôn thấy cả hai.
- `sudo` bắt buộc cho root-protected paths như `sys/health`, `sys/auth/*`, `sys/mounts/*`.

## Các lệnh

```bash
# ============================================================
# Bước 1 — Tạo dữ liệu thử nghiệm trên KV v2
# ============================================================

# KV v2 đã được mount sẵn tại secret/ trong dev server
# Tạo secret cho webapp (path được phép)
vault kv put -mount=secret webapp/config \
  db_host="localhost" \
  db_port="5432"

# Tạo secret cho ứng dụng khác (path bị từ chối với webapp token)
vault kv put -mount=secret other-app/config \
  api_key="super-secret-key"

# ============================================================
# Bước 2 — Viết file HCL và tạo webapp policy
# ============================================================

# Tạo file HCL cho webapp policy
cat > /tmp/webapp-policy.hcl << 'EOF'
# Quyền đọc/ghi trên data path của KV v2 cho webapp
path "secret/data/webapp/*" {
  capabilities = ["create", "read", "update", "delete"]
}

# Quyền list trên metadata path — cần cho vault kv list
path "secret/metadata/webapp/*" {
  capabilities = ["list"]
}
EOF

# Ghi policy vào Vault
vault policy write webapp /tmp/webapp-policy.hcl

# Xác nhận policy đã được ghi
vault policy read webapp

# ============================================================
# Bước 3 — Tạo token với webapp policy
# ============================================================

# Tạo token và lưu vào biến
WEBAPP_TOKEN=$(vault token create -format=json -policy="webapp" | jq -r ".auth.client_token")
echo "Webapp token: $WEBAPP_TOKEN"

# ============================================================
# Bước 4 — Kiểm tra policies gắn với token
# ============================================================

# Lookup token — xem trường policies, phải có "default" và "webapp"
vault token lookup "$WEBAPP_TOKEN"

# Kiểm tra capabilities trên path được phép — phải thấy [create delete read update]
vault token capabilities "$WEBAPP_TOKEN" secret/data/webapp/config

# Kiểm tra capabilities trên path bị từ chối — phải thấy [] hoặc deny
vault token capabilities "$WEBAPP_TOKEN" secret/data/other-app/config

# ============================================================
# Bước 5 — Đăng nhập bằng webapp token và kiểm tra thực tế
# ============================================================

# Đăng nhập bằng webapp token
vault login "$WEBAPP_TOKEN"

# Thử đọc secret được phép — phải thành công
vault kv get -mount=secret webapp/config

# Thử đọc secret bị từ chối — phải thấy "permission denied"
vault kv get -mount=secret other-app/config || echo "Lỗi permission denied — đúng như mong đợi"

# Quay lại root token để tiếp tục làm việc
vault login root

# ============================================================
# Bước 6 — Tạo operator policy với sys/* và sudo
# ============================================================

cat > /tmp/operator-policy.hcl << 'EOF'
# Đọc trạng thái sức khỏe cluster — root-protected path
path "sys/health" {
  capabilities = ["read", "sudo"]
}

# Xem danh sách ACL policies
path "sys/policies/acl" {
  capabilities = ["list"]
}

# Quản lý ACL policies — root-protected
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Xem danh sách auth methods đã enable
path "sys/auth" {
  capabilities = ["read"]
}

# Quản lý auth methods — root-protected
path "sys/auth/*" {
  capabilities = ["create", "update", "delete", "sudo"]
}

# Xem danh sách secrets engines đã mount
path "sys/mounts" {
  capabilities = ["read"]
}

# Quản lý secrets engine mounts — root-protected
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

# Ghi operator policy vào Vault
vault policy write operator /tmp/operator-policy.hcl

# Xác nhận
vault policy read operator

# ============================================================
# Bước 7 — Tạo token operator và kiểm tra
# ============================================================

# Tạo token operator
OPERATOR_TOKEN=$(vault token create -format=json -policy="operator" | jq -r ".auth.client_token")
echo "Operator token: $OPERATOR_TOKEN"

# Lookup để xác nhận policies
vault token lookup "$OPERATOR_TOKEN"

# Kiểm tra capabilities tại sys/health — phải thấy [read sudo]
vault token capabilities "$OPERATOR_TOKEN" sys/health
```

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
