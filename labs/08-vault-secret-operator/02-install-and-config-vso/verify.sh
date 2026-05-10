#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Cài đặt VSO và khai báo VaultConnection + VaultAuth
#
# Quy ước:
#   pass "mô tả ngắn"  -> in dòng [PASS]
#   fail "mô tả ngắn"  -> in dòng [FAIL] và tăng số lỗi
#
# Mỗi assertion tương ứng với ít nhất một bước trong README.md.
# Exit code chỉ là 0 khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Cài đặt VSO và khai báo VaultConnection + VaultAuth"
echo

# --- Kiểm tra 0: Vault có thể truy cập -------------------------------------------
# Bước tiên quyết: Vault dev server phải đang chạy trong Codespace.
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 1: kubectl có thể kết nối đến cluster Kubernetes -------------------
# Đây là bài lab Kubernetes — cần cluster đang chạy.
if kubectl cluster-info >/dev/null 2>&1; then
  pass "kubectl có thể kết nối đến Kubernetes cluster"
else
  fail "Không kết nối được đến Kubernetes cluster — kiểm tra Kind hoặc kubeconfig"
  echo
  echo "Nếu dùng Kind, khởi động cluster bằng:"
  echo "  kind create cluster"
  exit 1
fi

# --- Kiểm tra 2: Helm repo hashicorp đã được thêm (Bước 1) -----------------------
# Kiểm tra xem repo hashicorp có trong danh sách repo Helm hay không.
if helm repo list 2>/dev/null | grep -q "hashicorp"; then
  pass "Helm repo 'hashicorp' đã được thêm"
else
  fail "Helm repo 'hashicorp' chưa được thêm — chạy: helm repo add hashicorp https://helm.releases.hashicorp.com"
fi

# --- Kiểm tra 3: Helm release vault-secrets-operator tồn tại (Bước 2) -----------
# Kiểm tra release VSO đã được cài trong namespace vault-secrets-operator.
if helm status vault-secrets-operator -n vault-secrets-operator >/dev/null 2>&1; then
  pass "Helm release 'vault-secrets-operator' tồn tại trong namespace vault-secrets-operator"
else
  fail "Helm release 'vault-secrets-operator' chưa được cài — chạy helm install theo hướng dẫn Bước 2"
fi

# --- Kiểm tra 4: Pod controller đang Running (Bước 3) ----------------------------
# Pod trong namespace vault-secrets-operator phải ở trạng thái Running.
POD_STATUS=$(kubectl get pods -n vault-secrets-operator \
  --field-selector=status.phase=Running \
  --no-headers 2>/dev/null | wc -l)
if [ "$POD_STATUS" -ge 1 ]; then
  pass "Ít nhất 1 Pod trong namespace vault-secrets-operator đang Running"
else
  fail "Không có Pod nào đang Running trong namespace vault-secrets-operator"
fi

# --- Kiểm tra 5: CRD vaultconnections đã đăng ký (Bước 3) -----------------------
if kubectl get crd vaultconnections.secrets.hashicorp.com >/dev/null 2>&1; then
  pass "CRD vaultconnections.secrets.hashicorp.com đã đăng ký"
else
  fail "CRD vaultconnections.secrets.hashicorp.com chưa có — VSO chưa cài đúng"
fi

# --- Kiểm tra 6: CRD vaultauths đã đăng ký (Bước 3) -----------------------------
if kubectl get crd vaultauths.secrets.hashicorp.com >/dev/null 2>&1; then
  pass "CRD vaultauths.secrets.hashicorp.com đã đăng ký"
else
  fail "CRD vaultauths.secrets.hashicorp.com chưa có — VSO chưa cài đúng"
fi

# --- Kiểm tra 7: CRD vaultstaticsecrets đã đăng ký (Bước 3) ---------------------
if kubectl get crd vaultstaticsecrets.secrets.hashicorp.com >/dev/null 2>&1; then
  pass "CRD vaultstaticsecrets.secrets.hashicorp.com đã đăng ký"
else
  fail "CRD vaultstaticsecrets.secrets.hashicorp.com chưa có — VSO chưa cài đúng"
fi

# --- Kiểm tra 8: CRD vaultdynamicsecrets đã đăng ký (Bước 3) -------------------
if kubectl get crd vaultdynamicsecrets.secrets.hashicorp.com >/dev/null 2>&1; then
  pass "CRD vaultdynamicsecrets.secrets.hashicorp.com đã đăng ký"
else
  fail "CRD vaultdynamicsecrets.secrets.hashicorp.com chưa có — VSO chưa cài đúng"
fi

# --- Kiểm tra 9: Namespace app tồn tại (Bước 4) ----------------------------------
if kubectl get namespace app >/dev/null 2>&1; then
  pass "Namespace 'app' đã được tạo"
else
  fail "Namespace 'app' chưa tồn tại — chạy: kubectl create namespace app"
fi

# --- Kiểm tra 10: VaultConnection 'default' tồn tại trong namespace app (Bước 5) -
if kubectl get vaultconnection default -n app >/dev/null 2>&1; then
  pass "VaultConnection 'default' tồn tại trong namespace app"
else
  fail "VaultConnection 'default' chưa được tạo trong namespace app"
fi

# --- Kiểm tra 11: VaultConnection 'default' có field address (Bước 5) -----------
VCONN_ADDRESS=$(kubectl get vaultconnection default -n app \
  -o jsonpath='{.spec.address}' 2>/dev/null)
if [ -n "$VCONN_ADDRESS" ]; then
  pass "VaultConnection 'default' có field address: $VCONN_ADDRESS"
else
  fail "VaultConnection 'default' thiếu field spec.address"
fi

# --- Kiểm tra 12: ServiceAccount demo-static-app tồn tại trong namespace app (Bước 6) -
if kubectl get serviceaccount demo-static-app -n app >/dev/null 2>&1; then
  pass "ServiceAccount 'demo-static-app' tồn tại trong namespace app"
else
  fail "ServiceAccount 'demo-static-app' chưa được tạo trong namespace app"
fi

# --- Kiểm tra 13: VaultAuth 'static-auth' tồn tại trong namespace app (Bước 6) --
if kubectl get vaultauth static-auth -n app >/dev/null 2>&1; then
  pass "VaultAuth 'static-auth' tồn tại trong namespace app"
else
  fail "VaultAuth 'static-auth' chưa được tạo trong namespace app"
fi

# --- Kiểm tra 14: VaultAuth 'static-auth' cấu hình đúng method kubernetes (Bước 6) -
VAUTH_METHOD=$(kubectl get vaultauth static-auth -n app \
  -o jsonpath='{.spec.method}' 2>/dev/null)
if [ "$VAUTH_METHOD" = "kubernetes" ]; then
  pass "VaultAuth 'static-auth' dùng method: kubernetes"
else
  fail "VaultAuth 'static-auth' thiếu hoặc sai field spec.method (mong đợi: kubernetes, thực tế: ${VAUTH_METHOD:-<trống>})"
fi

# --- Kiểm tra 15: VaultAuth 'static-auth' tham chiếu đúng mount (Bước 6) --------
VAUTH_MOUNT=$(kubectl get vaultauth static-auth -n app \
  -o jsonpath='{.spec.mount}' 2>/dev/null)
if [ "$VAUTH_MOUNT" = "demo-auth-mount" ]; then
  pass "VaultAuth 'static-auth' có mount: demo-auth-mount"
else
  fail "VaultAuth 'static-auth' thiếu hoặc sai field spec.mount (mong đợi: demo-auth-mount, thực tế: ${VAUTH_MOUNT:-<trống>})"
fi

# --- Kiểm tra 16: Vault Kubernetes auth method demo-auth-mount đã enable (Bước 7) -
if vault auth list 2>/dev/null | grep -q "demo-auth-mount"; then
  pass "Vault Kubernetes auth method 'demo-auth-mount' đã được enable"
else
  fail "Vault auth method 'demo-auth-mount' chưa enable — chạy: vault auth enable -path demo-auth-mount kubernetes"
fi

# --- Kiểm tra 17: Vault policy 'webapp' tồn tại (Bước 7) -------------------------
if vault policy read webapp >/dev/null 2>&1; then
  pass "Vault policy 'webapp' tồn tại"
else
  fail "Vault policy 'webapp' chưa được tạo — xem Bước 7 trong README.md"
fi

# --- Kiểm tra 18: Vault policy 'webapp' có path KV v2 đúng (Bước 7) -------------
# Policy KV v2 phải có /data/ trong path
POLICY_CONTENT=$(vault policy read webapp 2>/dev/null)
if echo "$POLICY_CONTENT" | grep -q "kvv2/data/webapp/config"; then
  pass "Vault policy 'webapp' có path KV v2 đúng (kvv2/data/webapp/config)"
else
  fail "Vault policy 'webapp' thiếu path 'kvv2/data/webapp/config' — KV v2 bắt buộc phải có /data/ trong policy path"
fi

# --- Kiểm tra 19: Vault role 'role1' tồn tại trong auth mount demo-auth-mount (Bước 7) -
if vault read auth/demo-auth-mount/role/role1 >/dev/null 2>&1; then
  pass "Vault role 'role1' tồn tại tại auth/demo-auth-mount/role/role1"
else
  fail "Vault role 'role1' chưa được tạo tại auth/demo-auth-mount/role/role1"
fi

# --- Kiểm tra 20: Vault role 'role1' liên kết đúng ServiceAccount (Bước 7) ------
ROLE_SA=$(vault read -field=bound_service_account_names auth/demo-auth-mount/role/role1 2>/dev/null)
if echo "$ROLE_SA" | grep -q "demo-static-app"; then
  pass "Vault role 'role1' liên kết với ServiceAccount 'demo-static-app'"
else
  fail "Vault role 'role1' chưa liên kết với ServiceAccount 'demo-static-app'"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
