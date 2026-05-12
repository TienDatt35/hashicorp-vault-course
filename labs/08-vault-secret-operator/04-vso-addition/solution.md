---
title: Đáp án mẫu — Secret Transformation
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này tập trung vào `destination.transformation` trong VaultStaticSecret. VSO đọc secret từ Vault (với field gốc là `username` và `password`), rồi áp dụng transformation trước khi ghi ra K8s Secret:

- **Bước 2-3**: Dùng `templates` để tạo key mới (`APP_USER`, `APP_PASS`) với nội dung lấy từ key gốc qua `get .Secrets`. Dùng `excludes` để loại bỏ key gốc. Lưu ý rằng `excludes` không loại bỏ key do template tạo ra — chỉ loại bỏ key gốc từ Vault.

- **Bước 4**: Dùng `excludeRaw: true` kết hợp `templates` để tạo `DATABASE_URL` tổng hợp. `excludeRaw: true` mạnh hơn `excludes` — nó loại bỏ hoàn toàn tất cả raw data gốc, K8s Secret chỉ chứa kết quả template.

## Bước 1: Xác minh môi trường từ bài trước

```bash
# Kiểm tra secret kvv2/webapp/config tồn tại
vault kv get kvv2/webapp/config

# Kiểm tra namespace app và VaultAuth static-auth
kubectl get namespace app
kubectl get vaultauth static-auth -n app
```

Nếu thiếu, bổ sung:

```bash
# Tạo namespace app nếu chưa có
kubectl create namespace app

# Ghi secret nếu chưa có
vault kv put kvv2/webapp/config username="appuser" password="s3cr3t"
```

## Bước 2: Tạo VaultStaticSecret với transformation đổi tên key

Tạo file manifest và apply:

```bash
kubectl apply -f - <<EOF
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  namespace: app
  name: webapp-transform
spec:
  vaultAuthRef: static-auth
  mount: kvv2
  type: kv-v2
  path: webapp/config
  refreshAfter: 5m
  destination:
    create: true
    name: webapp-transformed
    transformation:
      excludes:
        - "username|password"
      templates:
        APP_USER:
          text: |
            {{- get .Secrets "username" -}}
        APP_PASS:
          text: |
            {{- get .Secrets "password" -}}
EOF
```

**Giải thích:**

- `excludes: ["username|password"]` — dùng RE2 regex loại bỏ hai key gốc từ Vault khỏi K8s Secret.
- `templates.APP_USER.text` — Go template dùng hàm `get .Secrets "username"` để đọc giá trị của key `username` từ Vault secret và gán cho key mới `APP_USER`.
- `{{- ... -}}` — dấu gạch ngang cắt whitespace ở đầu và cuối, tránh xuống dòng thừa trong giá trị.

## Bước 3: Xác minh K8s Secret có đúng key mới

```bash
# Xem danh sách key trong K8s Secret (chỉ xem tên key, không giải mã giá trị)
kubectl get secret webapp-transformed -n app -o jsonpath='{.data}' | jq '.'

# Hoặc xem toàn bộ YAML (giá trị ở dạng base64)
kubectl get secret webapp-transformed -n app -o yaml

# Giải mã giá trị APP_USER để xác minh nội dung đúng
kubectl get secret webapp-transformed -n app \
  -o jsonpath='{.data.APP_USER}' | base64 -d
# Kết quả mong đợi: appuser

# Xác minh key gốc không còn tồn tại
kubectl get secret webapp-transformed -n app \
  -o jsonpath='{.data.username}'
# Kết quả mong đợi: (trống — key không tồn tại)
```

## Bước 4: Tạo VaultStaticSecret reshape thành DATABASE_URL

```bash
kubectl apply -f - <<EOF
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  namespace: app
  name: webapp-reshape
spec:
  vaultAuthRef: static-auth
  mount: kvv2
  type: kv-v2
  path: webapp/config
  refreshAfter: 5m
  destination:
    create: true
    name: webapp-reshaped
    transformation:
      excludeRaw: true
      templates:
        DATABASE_URL:
          text: |
            {{- printf "postgresql://%s:%s@db-host:5432/mydb"
              (get .Secrets "username")
              (get .Secrets "password") -}}
EOF
```

**Giải thích:**

- `excludeRaw: true` — loại bỏ hoàn toàn tất cả raw data gốc từ Vault. K8s Secret chỉ chứa `DATABASE_URL`, không có `username` hay `password` hay bất kỳ field nào khác.
- `printf "postgresql://%s:%s@..."` — Go template function `printf` để format chuỗi connection URL, với `%s` được thay bằng giá trị thực.

### Xác minh kết quả reshape

```bash
# Xem DATABASE_URL đã được tạo
kubectl get secret webapp-reshaped -n app \
  -o jsonpath='{.data.DATABASE_URL}' | base64 -d
# Kết quả mong đợi: postgresql://appuser:s3cr3t@db-host:5432/mydb

# Xác minh không có key gốc
kubectl get secret webapp-reshaped -n app -o yaml
# Trong phần data, chỉ có DATABASE_URL, không có username hay password
```

## Bước 5 (Conceptual): Về Encrypted Client Cache

Cache được lưu trong **Kubernetes Secret** (tên dạng `vso-cc-<hash>`), không phải trong memory. Điều này có nghĩa cache tồn tại qua các lần restart của operator pod.

Engine Vault được dùng để mã hóa cache là **Transit engine**. Nội dung cache được mã hóa trước khi ghi vào K8s Secret, đảm bảo ngay cả admin Kubernetes cũng không thể đọc được nội dung cache.

Lý do cần giữ lease sau restart: Dynamic secrets (database credential, cloud IAM) có Vault lease gắn với chúng. Nếu operator restart mà mất thông tin lease, Vault không thể renew và credential sẽ hết hạn sớm. Nếu phải tạo credential mới sau mỗi restart, điều này lãng phí tài nguyên và có thể làm cạn pool kết nối database.

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
