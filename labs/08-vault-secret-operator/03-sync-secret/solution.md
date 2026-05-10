---
title: Đáp án mẫu — Đồng bộ secret từ Vault vào Kubernetes với 3 CRD
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài này thực hành vòng đời đầy đủ của cả ba CRD sync: chuẩn bị phía Vault
(enable engine, ghi dữ liệu, tạo policy), rồi khai báo CRD trong Kubernetes
để VSO controller tự động đọc Vault và tạo Kubernetes Secret. Điểm mấu chốt
là hiểu rõ mối quan hệ giữa `vaultAuthRef`, `mount`/`path` trên Vault,
và `destination` là Secret đầu ra.

---

## Bước 1 — Chuẩn bị Vault: enable KV v2 và ghi secret

```bash
# Enable KV v2 secrets engine tại path kvv2
vault secrets enable -path=kvv2 kv-v2

# Ghi secret vào kvv2/webapp/config
vault kv put kvv2/webapp/config username="appuser" password="s3cr3t"

# Tạo (hoặc cập nhật) policy webapp
# Lưu ý: path trong policy PHẢI có /data/ cho KV v2
vault policy write webapp - <<'EOF'
path "kvv2/data/webapp/config" {
  capabilities = ["read"]
}
EOF

# Xác minh secret đã được ghi
vault kv get kvv2/webapp/config
```

**Tại sao policy cần `/data/`?**
KV v2 engine lưu dữ liệu tại endpoint `<mount>/data/<path>` trong Vault API.
Policy phải phản ánh đúng endpoint thực, nên bắt buộc có `/data/`. Trong CRD,
bạn chỉ viết path người dùng (không có `/data/`) — VSO tự thêm phần này.

---

## Bước 2 — Khai báo VaultStaticSecret

```bash
# Tạo file manifest
cat <<'EOF' > /tmp/vault-static-secret.yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  namespace: app
  name: webapp-static
spec:
  vaultAuthRef: static-auth
  mount: kvv2
  type: kv-v2
  path: webapp/config
  refreshAfter: 60s
  destination:
    create: true
    name: webapp-static-secret
    type: Opaque
EOF

# Apply manifest
kubectl apply -f /tmp/vault-static-secret.yaml

# Đợi VSO xử lý (thường mất 5-10 giây)
sleep 10

# Kiểm tra VaultStaticSecret đã được tạo
kubectl get vaultstaticsecret webapp-static -n app

# Kiểm tra Kubernetes Secret đã được tạo
kubectl get secret webapp-static-secret -n app

# Xem nội dung Secret (dữ liệu được base64 encode)
kubectl get secret webapp-static-secret -n app -o jsonpath='{.data}'
```

**Lưu ý quan trọng:**
- `type: kv-v2` là loại engine, không phải loại K8s Secret
- `destination.create: true` bắt buộc để VSO tạo Secret mới
- Nếu Secret không xuất hiện, chạy `kubectl describe vaultstaticsecret webapp-static -n app` để xem lỗi

---

## Bước 3 — Enable database engine và khai báo VaultDynamicSecret

```bash
# Enable database secrets engine
vault secrets enable -path=db database

# Tạo policy vso-dynamic
vault policy write vso-dynamic - <<'EOF'
path "db/creds/my-postgresql-role" {
  capabilities = ["read"]
}
EOF

# Cập nhật Vault role role1 để gồm cả hai policy webapp và vso-dynamic
# (Cần biết Kubernetes API server address)
KUBE_API=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

vault write auth/demo-auth-mount/role/role1 \
  bound_service_account_names=demo-static-app \
  bound_service_account_namespaces=app \
  policies="webapp,vso-dynamic" \
  audience=vault \
  ttl=24h

# Khai báo VaultDynamicSecret
# Lưu ý: vì không có PostgreSQL thực, VSO sẽ tạo Secret nhưng có thể báo lỗi
# khi cố sinh credential thực tế — verify.sh chỉ kiểm tra resource đã tồn tại
cat <<'EOF' > /tmp/vault-dynamic-secret.yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  namespace: app
  name: webapp-dynamic
spec:
  vaultAuthRef: static-auth
  mount: db
  path: creds/my-postgresql-role
  renewalPercent: 67
  revoke: true
  destination:
    create: true
    name: dynamic-db-creds
EOF

kubectl apply -f /tmp/vault-dynamic-secret.yaml

# Kiểm tra VaultDynamicSecret đã được tạo
kubectl get vaultdynamicsecret webapp-dynamic -n app

# Kiểm tra Secret (có thể có hoặc không có dữ liệu tùy thuộc vào DB config)
kubectl get secret dynamic-db-creds -n app 2>/dev/null || echo "Secret chưa tạo — có thể do lỗi DB config, xem describe"
```

**Tại sao dùng `revoke: true`?**
Khi xóa VaultDynamicSecret, với `revoke: true` VSO gửi yêu cầu revoke lease
đến Vault ngay lập tức. Nếu để mặc định `false`, credential cũ tồn tại đến
hết TTL tự nhiên (1 giờ trong ví dụ này) — rủi ro bảo mật trên production.

---

## Bước 4 — Enable PKI engine và khai báo VaultPKISecret

```bash
# Enable PKI secrets engine
vault secrets enable pki

# Đặt max lease TTL cho PKI engine
vault secrets tune -max-lease-ttl=8760h pki

# Tạo root CA certificate
vault write pki/root/generate/internal \
  common_name="example.com" \
  ttl=8760h

# Cấu hình URL cho issuing certificate và CRL distribution
vault write pki/config/urls \
  issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
  crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"

# Tạo PKI role default
vault write pki/roles/default \
  allowed_domains="example.com" \
  allow_subdomains=true \
  max_ttl="72h"

# Tạo policy vso-pki
vault policy write vso-pki - <<'EOF'
path "pki/issue/default" {
  capabilities = ["create", "update"]
}
EOF

# Cập nhật Vault role role1 để gồm cả ba policy
vault write auth/demo-auth-mount/role/role1 \
  bound_service_account_names=demo-static-app \
  bound_service_account_namespaces=app \
  policies="webapp,vso-dynamic,vso-pki" \
  audience=vault \
  ttl=24h

# Khai báo VaultPKISecret
cat <<'EOF' > /tmp/vault-pki-secret.yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultPKISecret
metadata:
  namespace: app
  name: webapp-pki
spec:
  vaultAuthRef: static-auth
  mount: pki
  role: default
  commonName: example.com
  ttl: 72h
  format: pem
  expiryOffset: 5m
  revoke: true
  destination:
    create: true
    name: pki-tls-secret
    type: kubernetes.io/tls
EOF

kubectl apply -f /tmp/vault-pki-secret.yaml

# Đợi VSO xử lý và cấp cert
sleep 15

# Kiểm tra VaultPKISecret đã được tạo
kubectl get vaultpkisecret webapp-pki -n app

# Kiểm tra Secret TLS đã được tạo với đúng type
kubectl get secret pki-tls-secret -n app

# Xác minh có cả tls.crt và tls.key
kubectl get secret pki-tls-secret -n app -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout 2>/dev/null | grep "Subject:"
```

**Tại sao dùng `kubernetes.io/tls`?**
Kubernetes Secret có type `kubernetes.io/tls` được validate rằng phải có đủ
key `tls.crt` và `tls.key`. Ingress controller và nhiều workload HTTPS mong
đợi format này. VSO tự động đặt dữ liệu vào đúng key khi dùng VaultPKISecret.

---

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
