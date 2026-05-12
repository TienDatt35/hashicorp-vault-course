---
title: Đáp án mẫu — Thực hành nhận diện Vault Agent và Proxy
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách viết HCL khác cũng đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này tập trung vào việc nhận diện cú pháp HCL của Vault Agent và Vault Proxy. Bạn chưa cần chạy daemon thực — chỉ cần viết đúng cấu trúc stanza để hiểu thiết kế của mỗi daemon. `verify.sh` dùng `grep` để kiểm tra các stanza bắt buộc có xuất hiện trong file HCL không.

## Bước 1: Khám phá CLI

```bash
vault agent --help
vault proxy --help
```

Hai lệnh này đều nhận flag `-config` để chỉ định file HCL. Sự khác biệt chính ở phần mô tả: Agent nói về templating và process supervisor, Proxy nói về API proxy và không đề cập templating.

## Bước 2: Tạo file cấu hình Agent

```bash
cat > /tmp/lab-agent.hcl << 'EOF'
vault {
  address = "http://127.0.0.1:8200"
}

auto_auth {
  method {
    type = "approle"
    config = {
      role_id_file_path   = "/tmp/lab-role-id"
      secret_id_file_path = "/tmp/lab-secret-id"
    }
  }

  sink {
    type = "file"
    config = {
      path = "/tmp/lab-vault-token"
    }
  }
}

cache {}

template {
  source      = "/tmp/lab-template.tmpl"
  destination = "/tmp/lab-app.env"
}
EOF
```

**Giải thích cấu trúc:**
- `vault {}` — chỉ định địa chỉ Vault server thực, không dùng VAULT_ADDR để tránh vòng lặp nếu Agent mở listener.
- `auto_auth {}` — chứa cả `method` (loại xác thực) và `sink` (nơi ghi token). Đây là stanza trung tâm của Agent.
- `cache {}` — để trống là đủ để bật caching với cấu hình mặc định.
- `template {}` — chỉ định file template nguồn và đích render. Trong thực tế, file template phải tồn tại trước khi Agent chạy.

## Bước 3: Tạo file cấu hình Proxy

```bash
cat > /tmp/lab-proxy.hcl << 'EOF'
vault {
  address = "http://127.0.0.1:8200"
}

auto_auth {
  method {
    type = "approle"
    config = {
      role_id_file_path   = "/tmp/lab-role-id"
      secret_id_file_path = "/tmp/lab-secret-id"
    }
  }

  sink {
    type = "file"
    config = {
      path = "/tmp/lab-proxy-token"
    }
  }
}

listener "tcp" {
  address     = "127.0.0.1:8100"
  tls_disable = true
}

api_proxy {
  use_auto_auth_token = true
}

cache {}
EOF
```

**Giải thích cấu trúc:**
- `listener "tcp" {}` — bắt buộc trong Proxy; mở cổng để nhận Vault API request từ ứng dụng.
- `api_proxy {}` — bắt buộc trong Proxy; `use_auto_auth_token = true` nghĩa là Proxy dùng token tự xác thực được để forward request, không yêu cầu ứng dụng cung cấp token riêng.
- Không có stanza `template {}` — Proxy không hỗ trợ templating.

## Bước 4: So sánh hai file

```bash
echo "=== Agent config ===" && cat /tmp/lab-agent.hcl && echo && echo "=== Proxy config ===" && cat /tmp/lab-proxy.hcl
```

**Ba điểm khác biệt chính:**

1. **Proxy có `listener "tcp" {}` bắt buộc, Agent không bắt buộc** — Proxy phải mở listener để nhận request từ ứng dụng; Agent chỉ cần listener nếu muốn dùng caching như API proxy.

2. **Proxy có `api_proxy {}`, Agent không có** — Stanza này là định danh của Vault Proxy, cấu hình hành vi forward request.

3. **Agent có `template {}`, Proxy không có** — Templating là tính năng độc quyền của Agent, cho phép render file cấu hình từ secret Vault.

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
