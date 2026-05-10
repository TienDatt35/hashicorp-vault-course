---
title: Phân tích YAML manifest Vault Secrets Operator
estMinutes: 20
---

# Phân tích YAML manifest Vault Secrets Operator

## Mục tiêu

Bài thực hành này giúp bạn nắm vững cấu trúc các CRD của Vault Secrets Operator bằng cách đọc, phân tích và tự viết YAML manifest. Sau khi hoàn thành, bạn sẽ biết cách khai báo `VaultStaticSecret`, viết Vault policy tối thiểu tương ứng, và phân biệt manifest VSO với annotation của Agent Injector.

## Yêu cầu

- Bạn đã đọc bài lý thuyết "Giới thiệu Vault Secrets Operator" trong `site/docs/08-vault-secret-operator/01-vso-introduction/`.
- Bài thực hành này **không yêu cầu Kubernetes cluster thực** — bạn chỉ cần tạo và chỉnh sửa các file YAML và HCL.
- Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với token `root` (do devcontainer khởi động), nhưng bài này không yêu cầu kết nối Vault.

## Dữ liệu đầu vào

Đọc kỹ các manifest sau. Bạn sẽ cần phân tích chúng trong các bước bên dưới.

### manifest-1.yaml (cho Bước 1)

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  name: vault-prod
  namespace: payments
spec:
  address: "https://vault.internal:8200"
  skipTLSVerify: false
---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: payments-auth
  namespace: payments
spec:
  vaultConnectionRef: vault-prod
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: payments-reader
    serviceAccount: payments-sa
```

### Manifest A và Manifest B (cho Bước 4)

**Manifest A:**

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: my-secret
  namespace: production
spec:
  type: kv-v2
  mount: secret
  path: myapp/config
  destination:
    name: app-secret
    create: true
```

**Manifest B — Pod annotation:**

```yaml
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: "my-role"
vault.hashicorp.com/agent-inject-secret-config.yaml: "secret/data/myapp/config"
```

---

## Nhiệm vụ của bạn

### Bước 1 — Phân tích VaultConnection và VaultAuth

Đọc `manifest-1.yaml` ở trên và trả lời các câu hỏi sau bằng cách tạo file `answers.yaml` trong thư mục làm việc của bạn (ví dụ: `/tmp/lab-vso/answers.yaml`):

- `bước_1.vault_connection_address`: Vault server trong `VaultConnection` này nằm ở địa chỉ nào?
- `bước_1.vault_auth_method`: `VaultAuth` sử dụng method xác thực nào?
- `bước_1.vault_auth_role`: Vault role nào được khai báo trong `VaultAuth`?

File `answers.yaml` phải có cấu trúc YAML hợp lệ với các key trên.

### Bước 2 — Viết VaultStaticSecret

Tạo file `my-vss.yaml` trong thư mục làm việc của bạn. File này phải là một manifest `VaultStaticSecret` đáp ứng tất cả yêu cầu sau:

- Đồng bộ secret KV v2 tại path `myapp/database` từ mount có tên `secret`.
- Tạo Kubernetes Secret có tên `db-secret` trong namespace `default` (tự tạo nếu chưa có).
- Tham chiếu đến `VaultAuth` có tên `static-auth`.
- Re-fetch từ Vault mỗi **60 giây**.
- Trigger rolling restart cho `Deployment` có tên `backend` khi secret thay đổi.

### Bước 3 — Xác định Vault policy

Viết nội dung Vault policy HCL tối thiểu vào file `vault-policy.hcl` trong thư mục làm việc của bạn. Policy này phải:

- Cho phép VSO đọc secret tại path KV v2 tương ứng với Bước 2.
- Dùng đúng path convention của KV v2 (`<mount>/data/<path>`).
- Chỉ cấp quyền cần thiết tối thiểu (nguyên tắc least privilege).

### Bước 4 — Nhận diện manifest

Đọc Manifest A và Manifest B ở phần "Dữ liệu đầu vào". Bổ sung vào file `answers.yaml` của bạn (từ Bước 1) thêm phần `bước_4` với:

- `bước_4.manifest_vso`: Chữ cái (`A` hoặc `B`) của manifest thuộc Vault Secrets Operator.
- `bước_4.manifest_agent_injector`: Chữ cái của manifest thuộc Vault Agent Injector.
- `bước_4.ly_do`: Một câu giải thích ngắn lý do bạn nhận biết như vậy.

> Gợi ý: Hãy chú ý đến `apiVersion`, `kind`, và cách secret được khai báo trong mỗi manifest trước khi mở `solution.md`.

---

## Thư mục làm việc

Bạn có thể tạo các file trong thư mục bất kỳ. Script `verify.sh` sẽ tìm kiếm file trong thư mục hiện tại **và** trong `/tmp/lab-vso/`. Nếu bạn dùng `/tmp/lab-vso/`, hãy chạy:

```bash
mkdir -p /tmp/lab-vso
```

rồi tạo các file trong đó.

---

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
