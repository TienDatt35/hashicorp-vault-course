---
title: Bài 1.1 — Vault dev server đầu tiên của bạn
estMinutes: 15
---

# Bài 1.1 — Vault dev server đầu tiên của bạn

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?repo=TienDatt35/hashicorp-vault-course&devcontainer_path=labs%2F01-fundamentals%2F01-dev-server-first-steps%2F.devcontainer%2Fdevcontainer.json)

## Mục tiêu

Khởi động một Vault dev server, kiểm tra trạng thái, ghi và đọc secret đầu tiên bằng KV v2 secrets engine.

## Yêu cầu

- Codespace này được tạo từ devcontainer của chính bài thực hành. Dev server đã được khởi động sẵn cho bạn bằng `make setup` (qua `postCreateCommand`). Nếu cần khởi động lại, chạy `make reset`.
- Các biến môi trường `VAULT_ADDR=http://127.0.0.1:8200` và `VAULT_TOKEN=root` đã được thiết lập sẵn trong shell.

## Nhiệm vụ của bạn

1. Kiểm tra dev server đang chạy:
   ```bash
   vault status
   ```
   Bạn sẽ thấy `Sealed: false` và `Initialized: true`.
2. Liệt kê các secrets engine đang mount và tìm `secret/`:
   ```bash
   vault secrets list
   ```
3. Ghi một secret tại đường dẫn `secret/hello` với khóa `message` có giá trị `world`:
   ```bash
   # đến lượt bạn — hãy tự tìm ra lệnh
   ```
4. Đọc lại secret và xác nhận giá trị.
5. Chạy bộ kiểm tra:
   ```bash
   make verify
   ```
   Bạn phải thấy ba dòng `[PASS]` và dòng `Tất cả kiểm tra đều đạt.`

## Tiêu chí thành công

`make verify` thoát với mã 0 và mọi kiểm tra đều `[PASS]`:

- Vault có thể truy cập và đã unseal
- KV v2 secrets engine được mount tại `secret/`
- `secret/hello` chứa `message=world`

## Hiện đáp án

<details>
<summary>Hiển thị đáp án mẫu</summary>

```bash
vault kv put secret/hello message=world
vault kv get secret/hello
```

Hoặc chạy đáp án có sẵn:

```bash
make solution
```

</details>
