---
title: Vault Agent Templating
estMinutes: 20
---

# Vault Agent Templating

## Mục tiêu

Cấu hình Vault Agent để tự động render secret từ Vault ra file config trên đĩa, sử dụng block `template` và `template_config` kết hợp với auto-auth.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết về Vault Agent Templating.
- Các biến môi trường `VAULT_ADDR` và `VAULT_TOKEN` đã được thiết lập trong Codespace.

## Nhiệm vụ của bạn

### Bước 1 — Bật KV v2 engine và ghi secret

Bật secrets engine KV v2 tại path `secret` (nếu chưa bật). Sau đó ghi một secret tại `secret/myapp/config` với hai field:
- `username` có giá trị `admin`
- `password` có giá trị `s3cr3t`

### Bước 2 — Tạo Vault policy cho Agent

Tạo một file policy HCL tên là `agent-policy.hcl` trong thư mục `/tmp/lab-template/`. Policy này phải cho phép Agent đọc secret tại path `secret/data/myapp/config`.

Sau khi tạo file policy, apply nó vào Vault với tên `agent-policy`.

### Bước 3 — Tạo file template

Tạo thư mục `/tmp/lab-template/` nếu chưa có. Tạo file template `/tmp/lab-template/app-config.ctmpl` để render hai field `username` và `password` từ secret KV v2 vừa tạo ra file YAML.

Lưu ý: đây là KV v2, nên cú pháp truy cập field phải dùng đúng số lớp `data`.

### Bước 4 — Tạo file cấu hình Vault Agent

Tạo file `/tmp/lab-template/agent.hcl` với các thành phần:
- Block `vault` trỏ tới `http://127.0.0.1:8200`
- Block `auto_auth` dùng method `token_file` với path token file là `/tmp/vault-token-lab`
- Block `template_config` với `static_secret_render_interval = "10s"` (ngắn để dễ quan sát refresh)
- Block `template` trỏ source tới file `.ctmpl` vừa tạo, destination tới `/tmp/lab-output/config.yaml`, quyền file `0640`

Để Agent có token để xác thực, ghi root token vào file `/tmp/vault-token-lab`:

```bash
echo "root" > /tmp/vault-token-lab
```

Tạo thư mục output:

```bash
mkdir -p /tmp/lab-output
```

### Bước 5 — Chạy Vault Agent và kiểm tra output

Chạy Vault Agent ở background với file config vừa tạo. Sau vài giây, kiểm tra xem file `/tmp/lab-output/config.yaml` đã được tạo chưa.

Mở file output và xác nhận:
- File chứa giá trị `admin` cho username
- File chứa giá trị `s3cr3t` cho password
- File KHÔNG chứa cú pháp template `{{`

### Bước 6 (Nâng cao) — Xem auto-refresh hoạt động

Cập nhật secret với password mới:

```bash
vault kv put secret/myapp/config username="admin" password="newpassword123"
```

Chờ khoảng 15 giây (vì interval là 10 giây), rồi kiểm tra lại file `/tmp/lab-output/config.yaml`. Giá trị password phải được cập nhật tự động mà không cần khởi động lại Agent.

> Gợi ý: hãy tự suy nghĩ và tự viết các file config trước khi mở `solution.md`. Nếu bị kẹt ở cú pháp template hoặc cấu trúc HCL, hãy đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
