---
title: Transit Auto Unseal với Vault Dev Server
estMinutes: 20
---

# Transit Auto Unseal với Vault Dev Server

## Mục tiêu

Thực hành cấu hình Transit Auto Unseal: bạn sẽ dùng Vault A (dev server đang chạy sẵn tại port 8200) làm cluster trung tâm và khởi động Vault B ở chế độ production mode với `seal "transit"` trỏ về Vault A. Sau đó quan sát quá trình Vault B tự động unseal mà không cần nhập key thủ công.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này — Vault dev server đã chạy sẵn tại `http://127.0.0.1:8200` với root token là `root` (đây là Vault A).
- Bạn đã đọc bài lý thuyết Transit Auto Unseal.
- Terminal hỗ trợ mở nhiều tab hoặc bạn có thể dùng `tmux`/`screen`.

## Bối cảnh

Trong bài này bạn sẽ dùng 2 Vault instance:

| Instance | Port | Vai trò |
|---|---|---|
| Vault A | 8200 | Cluster trung tâm — Transit Secrets Engine |
| Vault B | 8300 | Cluster phụ — production mode với seal "transit" |

Vault A là dev server đã chạy sẵn. Vault B sẽ do bạn tự cấu hình và khởi động.

## Nhiệm vụ của bạn

### Phần 1 — Chuẩn bị Vault A (cluster trung tâm)

1. Kiểm tra Vault A đang sẵn sàng bằng lệnh `vault status` (đảm bảo `VAULT_ADDR` và `VAULT_TOKEN` đang trỏ về Vault A tại port 8200).

2. Enable Transit Secrets Engine trên Vault A.

3. Tạo một encryption key tên `autounseal-vault-b` trên Transit engine.

4. Tạo policy tên `autounseal-vault-b` trên Vault A với nội dung sau (copy nguyên để tạo policy):

   ```hcl
   path "transit/encrypt/autounseal-vault-b" {
     capabilities = ["update"]
   }
   path "transit/decrypt/autounseal-vault-b" {
     capabilities = ["update"]
   }
   ```

5. Tạo một orphan periodic token gắn policy `autounseal-vault-b`, TTL 24h. Lưu lại giá trị token này — bạn sẽ dùng ở Phần 2.

### Phần 2 — Cấu hình và khởi động Vault B

6. Tạo thư mục `/tmp/vault-b/` và file cấu hình `/tmp/vault-b/config.hcl` cho Vault B. File cấu hình phải bao gồm:
   - `seal "transit"` stanza trỏ về Vault A tại `http://127.0.0.1:8200`, key name là `autounseal-vault-b`, mount path là `transit/`
   - `storage "file"` với path `/tmp/vault-b/data`
   - `listener "tcp"` trên địa chỉ `127.0.0.1:8300` với `tls_disable = "true"`
   - `api_addr = "http://127.0.0.1:8300"`
   - `disable_mlock = true`

7. Export biến môi trường `VAULT_TOKEN` bằng token bạn tạo ở bước 5. Sau đó khởi động Vault B trong background:

   ```bash
   VAULT_TOKEN=<token-từ-bước-5> vault server -config=/tmp/vault-b/config.hcl > /tmp/vault-b/vault-b.log 2>&1 &
   ```

### Phần 3 — Khởi tạo và kiểm tra Vault B

8. Mở terminal mới (hoặc dùng một subshell). Set biến môi trường để làm việc với Vault B:

   ```bash
   export VAULT_ADDR=http://127.0.0.1:8300
   export VAULT_TOKEN=""
   ```

   Chờ vài giây rồi kiểm tra Vault B đã chạy bằng `vault status`. Vault B sẽ ở trạng thái `Sealed: true` và `Initialized: false`.

9. Khởi tạo Vault B:

   ```bash
   vault operator init -key-shares=5 -key-threshold=3 -format=json > /tmp/vault-b/init.json
   ```

   Quan sát output: Vault B sẽ sinh **Recovery Keys** (không phải Unseal Keys) và một root token.

10. Kiểm tra trạng thái Vault B sau khi init:

    ```bash
    vault status
    ```

    Xác nhận `Sealed: false` và xem trường `Recovery Seal Type` trong output.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra (từ terminal gốc, không phải terminal Vault B):

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
