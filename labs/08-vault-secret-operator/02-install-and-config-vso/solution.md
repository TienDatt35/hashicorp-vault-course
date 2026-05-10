---
title: Đáp án mẫu — Cài đặt VSO và khai báo VaultConnection + VaultAuth
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài thực hành này đi theo đúng thứ tự triển khai VSO: cài operator trước, sau đó khai báo các CRD kết nối và xác thực. Vault server cần được cấu hình Kubernetes auth method và policy trước khi VSO có thể thực sự đồng bộ secret — nhưng việc tạo VaultConnection và VaultAuth có thể thực hiện ngay sau khi cài VSO, ngay cả khi Vault chưa sẵn sàng (controller sẽ retry).

## Các lệnh

```bash
# ================================================================
# Bước 1 — Thêm Helm repo của HashiCorp
# ================================================================

# Đăng ký repo HashiCorp vào cấu hình Helm cục bộ
helm repo add hashicorp https://helm.releases.hashicorp.com

# Cập nhật danh sách chart từ tất cả các repo đã đăng ký
helm repo update hashicorp

# Tìm kiếm phiên bản có sẵn của chart VSO để xác nhận repo đã được thêm
helm search repo hashicorp/vault-secrets-operator --versions

# ================================================================
# Bước 2 — Cài đặt VSO bằng Helm với version pin
# ================================================================

helm install vault-secrets-operator hashicorp/vault-secrets-operator \
  --version 0.10.0 \
  --namespace vault-secrets-operator \
  --create-namespace

# Chờ controller khởi động (khoảng 30-60 giây)
kubectl rollout status deployment \
  -n vault-secrets-operator \
  vault-secrets-operator-controller-manager \
  --timeout=120s

# ================================================================
# Bước 3 — Xác minh sau cài đặt
# ================================================================

# Kiểm tra Pod đang Running
kubectl get pods -n vault-secrets-operator

# Kiểm tra 7 CRD đã đăng ký
kubectl get crds | grep secrets.hashicorp.com

# Kết quả mong đợi:
# hcpauths.secrets.hashicorp.com
# hcpvaultsecretsapps.secrets.hashicorp.com
# vaultauths.secrets.hashicorp.com
# vaultconnections.secrets.hashicorp.com
# vaultdynamicsecrets.secrets.hashicorp.com
# vaultpkisecrets.secrets.hashicorp.com
# vaultstaticsecrets.secrets.hashicorp.com

# ================================================================
# Bước 4 — Tạo namespace cho ứng dụng
# ================================================================

kubectl create namespace app

# ================================================================
# Bước 5 — Khai báo VaultConnection
# ================================================================

# Tìm địa chỉ IP của host từ bên trong Kind cluster
# (thường là gateway của bridge network docker0 hoặc địa chỉ node)
HOST_IP=$(ip route | grep default | awk '{print $3}' | head -1)
echo "Host IP: $HOST_IP"

cat <<EOF > vaultconnection.yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  name: default
  namespace: app
spec:
  address: "http://${HOST_IP}:8200"
EOF

kubectl apply -f vaultconnection.yaml

# Xác minh VaultConnection đã được tạo
kubectl get vaultconnection -n app

# ================================================================
# Bước 6 — Tạo ServiceAccount và khai báo VaultAuth
# ================================================================

# Tạo ServiceAccount mà VaultAuth sẽ tham chiếu
kubectl create serviceaccount demo-static-app -n app

# Tạo file VaultAuth
cat <<EOF > vaultauth.yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: static-auth
  namespace: app
spec:
  vaultConnectionRef: default
  method: kubernetes
  mount: demo-auth-mount
  kubernetes:
    role: role1
    serviceAccount: demo-static-app
    audiences:
      - vault
    tokenExpirationSeconds: 600
EOF

kubectl apply -f vaultauth.yaml

# Xác minh VaultAuth đã được tạo
kubectl get vaultauth -n app

# ================================================================
# Bước 7 — Cấu hình phía Vault server
# ================================================================

# Thiết lập biến môi trường Vault
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

# Lấy địa chỉ API server của Kind cluster
K8S_API=$(kubectl cluster-info | grep "Kubernetes control plane" | awk '{print $NF}' | sed 's/\x1b\[[0-9;]*m//g')
echo "Kubernetes API: $K8S_API"

# Enable Kubernetes auth method với path tùy chỉnh
vault auth enable -path demo-auth-mount kubernetes

# Cấu hình Kubernetes auth — trỏ đến API server của Kind cluster
# Quan trọng: Vault cần địa chỉ có thể truy cập từ máy host (không phải từ bên trong cluster)
vault write auth/demo-auth-mount/config \
  kubernetes_host="${K8S_API}"

# Tạo policy webapp cho phép đọc secret KV v2
# Lưu ý: KV v2 bắt buộc phải có /data/ trong path policy
vault policy write webapp - <<EOF
path "kvv2/data/webapp/config" {
  capabilities = ["read", "list"]
}
EOF

# Tạo Vault role liên kết ServiceAccount với policy
vault write auth/demo-auth-mount/role/role1 \
  bound_service_account_names=demo-static-app \
  bound_service_account_namespaces=app \
  policies=webapp \
  audience=vault \
  ttl=24h

# Xác minh cấu hình Vault
vault read auth/demo-auth-mount/role/role1
vault policy read webapp
```

## Giải thích chi tiết các bước quan trọng

### Tại sao phải dùng `--version` khi cài Helm

Nếu không chỉ định `--version`, Helm sẽ lấy phiên bản chart mới nhất tại thời điểm chạy lệnh. Giữa các phiên bản VSO có thể có breaking change về CRD schema. Bằng cách pin cố định `--version 0.10.0`, mọi lần cài lại trên bất kỳ cluster nào cũng cho kết quả nhất quán.

### Tại sao policy KV v2 cần có `/data/`

KV v2 engine tổ chức dữ liệu theo hai sub-path: `<mount>/data/<path>` chứa giá trị secret, và `<mount>/metadata/<path>` chứa version history. Khi VSO đọc secret, nó gọi đến sub-path `/data/`. Nếu policy chỉ khai báo `path "kvv2/webapp/config"` (thiếu `/data/`), Vault sẽ không khớp và trả về permission denied.

### Tại sao ServiceAccount phải cùng namespace với VaultAuth

VSO tìm ServiceAccount trong cùng namespace với VaultAuth để lấy JWT token. Đây là ràng buộc bảo mật: ngăn một namespace dùng ServiceAccount của namespace khác để xác thực với Vault, đảm bảo phân quyền theo namespace được giữ nguyên.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
