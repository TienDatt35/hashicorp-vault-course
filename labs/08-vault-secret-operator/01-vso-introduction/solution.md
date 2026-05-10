---
title: Đáp án mẫu — Phân tích YAML manifest Vault Secrets Operator
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này kiểm tra khả năng đọc hiểu cấu trúc CRD của Vault Secrets Operator và viết manifest đúng cú pháp. Điểm mấu chốt:

- `VaultStaticSecret` dùng `refreshAfter` (không phải `syncInterval` hay `ttl`).
- Path KV v2 trong Vault policy phải thêm `/data/` giữa mount name và path thực: `<mount>/data/<path>`.
- Phân biệt VSO (dùng CRD với `apiVersion: secrets.hashicorp.com/v1beta1`) và Agent Injector (dùng Pod annotation `vault.hashicorp.com/*`).

---

## Bước 1 — Phân tích VaultConnection và VaultAuth

Tạo thư mục và file đáp án:

```bash
mkdir -p /tmp/lab-vso
```

Nội dung file `answers.yaml` cho Bước 1:

```yaml
bước_1:
  vault_connection_address: "https://vault.internal:8200"
  vault_auth_method: "kubernetes"
  vault_auth_role: "payments-reader"
```

Giải thích:

- `vault_connection_address`: đọc từ field `spec.address` trong `VaultConnection`, giá trị là `https://vault.internal:8200`.
- `vault_auth_method`: đọc từ field `spec.method` trong `VaultAuth`, giá trị là `kubernetes`.
- `vault_auth_role`: đọc từ field `spec.kubernetes.role` trong `VaultAuth`, giá trị là `payments-reader`.

---

## Bước 2 — Viết VaultStaticSecret

Tạo file `/tmp/lab-vso/my-vss.yaml`:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: db-secret-sync
  namespace: default
spec:
  type: kv-v2
  mount: secret
  path: myapp/database
  vaultAuthRef: static-auth
  refreshAfter: 60s
  destination:
    name: db-secret
    create: true
  rolloutRestartTargets:
    - kind: Deployment
      name: backend
```

Lưu ý quan trọng:

- `type: kv-v2` — chỉ định loại KV engine.
- `mount: secret` — tên mount, không phải full path.
- `path: myapp/database` — path trong engine, VSO tự thêm `data/` khi gọi KV v2 API.
- `refreshAfter: 60s` — VSO re-fetch mỗi 60 giây.
- `rolloutRestartTargets` — danh sách workload sẽ được restart khi secret thay đổi.

---

## Bước 3 — Vault policy tối thiểu

Tạo file `/tmp/lab-vso/vault-policy.hcl`:

```hcl
path "secret/data/myapp/database" {
  capabilities = ["read", "list"]
}
```

Giải thích:

- KV v2 lưu secret tại đường dẫn thực `<mount>/data/<path>` trong Vault internal storage.
- Mặc dù trong `VaultStaticSecret` bạn khai báo `path: myapp/database`, Vault policy phải dùng full path với `/data/` ở giữa: `secret/data/myapp/database`.
- Chỉ cấp `read` và `list` — VSO không cần write hay delete.

---

## Bước 4 — Nhận diện manifest

Bổ sung vào file `answers.yaml`:

```yaml
bước_1:
  vault_connection_address: "https://vault.internal:8200"
  vault_auth_method: "kubernetes"
  vault_auth_role: "payments-reader"

bước_4:
  manifest_vso: "A"
  manifest_agent_injector: "B"
  ly_do: "Manifest A dùng CRD VaultStaticSecret với apiVersion secrets.hashicorp.com/v1beta1 — đây là cách VSO khai báo nguồn secret. Manifest B dùng Pod annotation vault.hashicorp.com/* — đây là cách Agent Injector nhận biết Pod cần inject secret qua sidecar."
```

---

## Kiểm tra lại

```bash
bash /home/claude/hashicorp-vault-course/labs/08-vault-secret-operator/01-vso-introduction/verify.sh
```

Hoặc nếu bạn đang ở trong thư mục lab:

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
