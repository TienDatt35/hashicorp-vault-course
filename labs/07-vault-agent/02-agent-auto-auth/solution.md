---
title: Đáp án mẫu — Vault Agent Auto-Auth
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Vault Agent Auto-Auth hoạt động như một proxy xác thực: nó thay mặt ứng dụng thực hiện toàn bộ quy trình auth với Vault (ở đây dùng AppRole), nhận token, và ghi token vào một file (sink). Ứng dụng chỉ đọc file đó mà không cần biết về quá trình xác thực.

Trong bài này, chúng ta dùng `remove_secret_id_file_after_reading = false` thay vì giá trị mặc định `true`. Lý do: trong môi trường lab bạn có thể cần chạy lại Agent nhiều lần (ví dụ: khi chỉnh sửa config). Nếu để mặc định `true`, Agent sẽ xóa file `secret_id` sau lần đọc đầu tiên và các lần khởi động lại sẽ thất bại.

## Bước 1 — Chuẩn bị AppRole

```bash
# Bật AppRole auth method (nếu chưa bật)
vault auth enable approle

# Tạo policy cho phép đọc secret lab-test
vault policy write lab-agent-policy - <<EOF
path "secret/data/lab-test" {
  capabilities = ["read"]
}
EOF

# Tạo AppRole role tên "lab-agent" với policy vừa tạo
vault write auth/approle/role/lab-agent \
  token_policies="lab-agent-policy" \
  token_ttl=1h \
  token_max_ttl=4h

# Lấy role_id và ghi vào file
vault read -field=role_id auth/approle/role/lab-agent/role-id > ./role_id

# Tạo secret_id và ghi vào file
vault write -field=secret_id -f auth/approle/role/lab-agent/secret-id > ./secret_id

# Xác nhận hai file đã được tạo
cat ./role_id
cat ./secret_id
```

## Bước 2 — Viết file cấu hình Agent

```bash
cat > agent.hcl <<'EOF'
pid_file = "./vault-agent.pid"

vault {
  address = "http://127.0.0.1:8200"
}

auto_auth {
  method {
    type = "approle"
    config = {
      role_id_file_path                   = "./role_id"
      secret_id_file_path                 = "./secret_id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink {
    type = "file"
    config = {
      path = "./vault-token-sink"
      mode = 0640
    }
  }
}
EOF
```

Lưu ý: `remove_secret_id_file_after_reading = false` được đặt để tránh Agent xóa file `secret_id` sau lần đọc đầu, giúp bạn có thể khởi động lại Agent trong môi trường lab. Trong production, nên để mặc định `true` và có hệ thống cấp phát `secret_id` mới trước mỗi lần khởi động.

## Bước 3 — Chạy Vault Agent

**Lựa chọn A — Mở terminal thứ hai (khuyến nghị):**

Trong Codespace, mở terminal mới (biểu tượng `+` hoặc `Ctrl+Shift+\``) rồi chạy:

```bash
cd /workspaces/hashicorp-vault-course   # hoặc thư mục bạn đang làm việc
vault agent -config=./agent.hcl
```

Giữ terminal này mở và chuyển lại terminal cũ để thực hiện các bước tiếp theo.

**Lựa chọn B — Chạy ở background:**

```bash
vault agent -config=./agent.hcl > ./vault-agent.log 2>&1 &
AGENT_PID=$!
echo "Agent PID: $AGENT_PID"

# Đợi Agent khởi động và ghi sink
sleep 3

# Xem log để xác nhận không có lỗi
cat ./vault-agent.log
```

## Bước 4 — Xác nhận token trong sink

```bash
# Xem nội dung sink file
cat ./vault-token-sink

# Dùng token từ sink để lookup — token phải hợp lệ
vault token lookup "$(cat ./vault-token-sink)"
```

Output của `vault token lookup` sẽ hiển thị thông tin token, bao gồm `display_name`, `policies`, và `expire_time`.

## Bước 5 — Dùng token từ sink để đọc secret

```bash
# Tạo secret cần đọc (dùng root token)
vault kv put secret/lab-test message="hello from vault"

# Đọc secret bằng token từ sink
VAULT_TOKEN="$(cat ./vault-token-sink)" vault kv get secret/lab-test
```

Output phải hiển thị key `message` với giá trị `hello from vault`. Điều này xác nhận token trong sink có đủ quyền đọc path `secret/data/lab-test` theo policy `lab-agent-policy`.

## Bước 6 — Tạo sink thứ hai với wrap_ttl

Nếu Agent đang chạy ở background, dừng nó trước:

```bash
# Dừng Agent (nếu chạy background)
kill $AGENT_PID 2>/dev/null || pkill -f "vault agent" 2>/dev/null || true
sleep 1
```

Chỉnh sửa `agent.hcl` để thêm sink thứ hai:

```bash
cat > agent.hcl <<'EOF'
pid_file = "./vault-agent.pid"

vault {
  address = "http://127.0.0.1:8200"
}

auto_auth {
  method {
    type = "approle"
    config = {
      role_id_file_path                   = "./role_id"
      secret_id_file_path                 = "./secret_id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink {
    type = "file"
    config = {
      path = "./vault-token-sink"
      mode = 0640
    }
  }

  sink {
    type     = "file"
    wrap_ttl = "5m"
    config = {
      path = "./vault-token-sink-wrapped"
      mode = 0640
    }
  }
}
EOF
```

Khởi động lại Agent:

```bash
vault agent -config=./agent.hcl > ./vault-agent.log 2>&1 &
sleep 3
```

Xác nhận wrapping token:

```bash
# Sink thường — token thật, có thể lookup trực tiếp
vault token lookup "$(cat ./vault-token-sink)"

# Sink wrapped — Agent ghi JSON response (có trường "token", "ttl", v.v.)
# Cần extract trường "token" trước, KHÔNG truyền cả JSON vào vault unwrap
cat ./vault-token-sink-wrapped
# Output dạng: {"token":"hvs.xxx","accessor":"xxx","ttl":300,...}

# Extract wrapping token từ JSON
WRAP_TOKEN=$(jq -r '.token' ./vault-token-sink-wrapped)

# Wrapping token KHÔNG thể lookup như token thường — sẽ báo lỗi
vault token lookup "$WRAP_TOKEN"

# Unwrap để lấy token thật
vault unwrap "$WRAP_TOKEN"
```

Hành vi này xác nhận rằng sink wrapped chứa wrapping token chứ không phải token thật.

## Dọn dẹp sau bài thực hành

```bash
# Dừng Agent
pkill -f "vault agent" 2>/dev/null || true

# Xóa file tạm
rm -f ./role_id ./secret_id ./vault-token-sink ./vault-token-sink-wrapped
rm -f ./vault-agent.pid ./vault-agent.log ./agent.hcl
```

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
