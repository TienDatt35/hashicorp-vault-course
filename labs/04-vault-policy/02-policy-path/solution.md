---
title: Đáp án mẫu — Thực hành viết policy với path và capabilities
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này rèn luyện kỹ năng viết path đúng trong policy. Điểm mấu chốt cần ghi nhớ:

- **KV v2** dùng `secret/data/...` cho đọc/ghi và `secret/metadata/...` cho list — không thể dùng `secret/apps/...` trực tiếp trong policy.
- **Dynamic credentials** (AWS, database) được lấy bằng `vault read`, tương ứng capability `read` trong policy.
- **Quản lý policy** đi qua `sys/policies/acl/...` — cần hai rules: một cho path có wildcard và một cho path gốc để list.

## Các lệnh

```bash
# Bước 1 — Tạo file policy cho Jenkins (KV v2)
cat > jenkins-dev.hcl << 'EOF'
path "secret/data/apps/jenkins" {
  capabilities = ["create", "read", "update", "delete"]
}

path "secret/metadata/apps/jenkins" {
  capabilities = ["list"]
}
EOF

vault policy write jenkins-dev jenkins-dev.hcl

# Bước 2 — Tạo file policy lấy AWS dynamic credentials
cat > aws-consumer.hcl << 'EOF'
path "aws/creds/webapp-role" {
  capabilities = ["read"]
}
EOF

vault policy write aws-consumer aws-consumer.hcl

# Bước 3 — Tạo file policy quản lý policies
cat > policy-admin.hcl << 'EOF'
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policies/acl" {
  capabilities = ["list"]
}
EOF

vault policy write policy-admin policy-admin.hcl

# Bước 4 — Tạo secret test trong KV v2
vault kv put secret/apps/jenkins/config url=http://jenkins:8080

# Tạo token với policy jenkins-dev
JENKINS_TOKEN=$(vault token create -policy=jenkins-dev -format=json | jq -r '.auth.client_token')

# Dùng token đó để đọc secret (xác minh policy hoạt động)
VAULT_TOKEN=$JENKINS_TOKEN vault kv get secret/apps/jenkins/config

# Bước 5 — Xác minh tất cả policies đã được đăng ký
vault policy list
```

## Lưu ý về KV v2 path

Khi bạn chạy `vault kv put secret/apps/jenkins/config ...`, Vault CLI tự thêm tiền tố `data/` và gọi tới API `secret/data/apps/jenkins/config`. Vì vậy policy phải dùng path `secret/data/apps/jenkins`, không phải `secret/apps/jenkins`. Nếu nhầm lẫn path này, token với policy `jenkins-dev` sẽ nhận lỗi 403 khi cố đọc secret.

Tương tự, `vault kv list secret/apps/jenkins/` gọi tới `secret/metadata/apps/jenkins/` — đó là lý do cần rule riêng cho `secret/metadata/apps/jenkins`.

## Lưu ý về AWS credentials

Vault dev server không có AWS Secrets Engine được cấu hình sẵn, nên lệnh `vault read aws/creds/webapp-role` sẽ trả về lỗi "no handler". Điều này không ảnh hưởng tới bài thực hành — policy `aws-consumer` vẫn được tạo thành công và `verify.sh` chỉ kiểm tra sự tồn tại và nội dung của policy, không kiểm tra việc gọi AWS.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
