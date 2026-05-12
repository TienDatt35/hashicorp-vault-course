---
title: Đáp án mẫu — Vault Agent Templating
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này minh họa luồng hoàn chỉnh của Vault Agent Templating:

1. Auto-auth bằng `token_file` method — Agent đọc token từ file `/tmp/vault-token-lab`.
2. Template engine dùng token đó để đọc secret tại `secret/data/myapp/config`.
3. Agent render file `.ctmpl` thành file YAML thực sự tại `/tmp/lab-output/config.yaml`.
4. Mỗi `static_secret_render_interval` (10 giây trong lab này), Agent re-fetch secret và render lại nếu nội dung thay đổi.

Cú pháp `.Data.data.username` (hai chữ `data`) là bắt buộc vì đây là KV v2 — lớp `data` ngoài cùng là wrapper của API response, lớp `data` bên trong là nơi chứa các field thực tế bạn đã `kv put`.

## Các lệnh

```bash
# --- Bước 1: Chuẩn bị môi trường ---

# Tạo thư mục làm việc
mkdir -p /tmp/lab-template /tmp/lab-output

# Ghi token vào file để Agent dùng cho auto-auth
echo "root" > /tmp/vault-token-lab

# Bật KV v2 engine (nếu chưa bật — lỗi "already enabled" là bình thường)
vault secrets enable -path=secret kv-v2

# Ghi secret
vault kv put secret/myapp/config username="admin" password="s3cr3t"

# --- Bước 2: Tạo policy ---

cat > /tmp/lab-template/agent-policy.hcl <<'EOF'
path "secret/data/myapp/config" {
  capabilities = ["read"]
}
EOF

vault policy write agent-policy /tmp/lab-template/agent-policy.hcl

# --- Bước 3: Tạo file template ---

cat > /tmp/lab-template/app-config.ctmpl <<'EOF'
{{/* Template render database config từ Vault KV v2 */}}
{{ with secret "secret/data/myapp/config" }}
username: {{ .Data.data.username }}
password: {{ .Data.data.password }}
{{ end }}
EOF

# --- Bước 4: Tạo file cấu hình Vault Agent ---

cat > /tmp/lab-template/agent.hcl <<'EOF'
pid_file = "/tmp/agent-pid"

vault {
  address = "http://127.0.0.1:8200"
}

auto_auth {
  method {
    type = "token_file"
    config = {
      token_file_path = "/tmp/vault-token-lab"
    }
  }
}

template_config {
  static_secret_render_interval = "10s"
}

template {
  source      = "/tmp/lab-template/app-config.ctmpl"
  destination = "/tmp/lab-output/config.yaml"
  perms       = "0640"
}
EOF

# --- Bước 5: Chạy Vault Agent ở background ---

vault agent -config=/tmp/lab-template/agent.hcl > /tmp/lab-agent.log 2>&1 &
echo "Vault Agent PID: $!"

# Chờ vài giây để Agent xác thực và render file lần đầu
sleep 3

# Kiểm tra file output
cat /tmp/lab-output/config.yaml
```

Kết quả mong đợi sau `cat`:

```yaml

username: admin
password: s3cr3t

```

```bash
# --- Bước 6 (Nâng cao): Kiểm tra auto-refresh ---

# Cập nhật secret với password mới
vault kv put secret/myapp/config username="admin" password="newpassword123"

# Chờ interval (10 giây + buffer)
sleep 15

# File phải được cập nhật tự động
cat /tmp/lab-output/config.yaml
# Kết quả mong đợi: password: newpassword123
```

## Lưu ý khi dừng Agent

Vault Agent chạy ở background sẽ tiếp tục chạy sau khi bạn đóng terminal (trong cùng phiên Codespace). Để dừng Agent:

```bash
# Tìm PID
cat /tmp/agent-pid

# Dừng Agent
kill "$(cat /tmp/agent-pid)"
```

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
