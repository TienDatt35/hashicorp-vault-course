#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Đồng bộ secret từ Vault vào Kubernetes với 3 CRD
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

echo "Đang kiểm tra bài thực hành — Đồng bộ secret từ Vault vào Kubernetes với 3 CRD"
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

# --- Kiểm tra 2: KV v2 engine đã được enable tại path kvv2 (Bước 1) ---------------
# Kiểm tra engine kvv2 tồn tại trong danh sách secrets engine.
if vault secrets list 2>/dev/null | grep -q "^kvv2/"; then
  pass "KV v2 secrets engine đã được enable tại path 'kvv2'"
else
  fail "KV v2 secrets engine chưa được enable tại path 'kvv2' — chạy: vault secrets enable -path=kvv2 kv-v2"
fi

# --- Kiểm tra 3: Secret kvv2/webapp/config đã được ghi (Bước 1) ------------------
# Đọc secret để xác nhận tồn tại và có dữ liệu.
if vault kv get kvv2/webapp/config >/dev/null 2>&1; then
  pass "Secret 'kvv2/webapp/config' tồn tại trên Vault"
else
  fail "Secret 'kvv2/webapp/config' chưa được ghi — chạy: vault kv put kvv2/webapp/config username=appuser password=s3cr3t"
fi

# --- Kiểm tra 4: Vault policy 'webapp' có path KV v2 đúng (Bước 1) ---------------
# Policy phải có /data/ trong path cho KV v2 engine.
WEBAPP_POLICY=$(vault policy read webapp 2>/dev/null)
if echo "$WEBAPP_POLICY" | grep -q "kvv2/data/webapp/config"; then
  pass "Vault policy 'webapp' có path KV v2 đúng (kvv2/data/webapp/config)"
else
  fail "Vault policy 'webapp' thiếu path 'kvv2/data/webapp/config' — KV v2 bắt buộc có /data/ trong policy path"
fi

# --- Kiểm tra 5: VaultStaticSecret 'webapp-static' tồn tại trong namespace app (Bước 2) -
if kubectl get vaultstaticsecret webapp-static -n app >/dev/null 2>&1; then
  pass "VaultStaticSecret 'webapp-static' tồn tại trong namespace app"
else
  fail "VaultStaticSecret 'webapp-static' chưa được tạo trong namespace app"
fi

# --- Kiểm tra 6: VaultStaticSecret 'webapp-static' cấu hình đúng type engine (Bước 2) -
VSS_TYPE=$(kubectl get vaultstaticsecret webapp-static -n app \
  -o jsonpath='{.spec.type}' 2>/dev/null)
if [ "$VSS_TYPE" = "kv-v2" ]; then
  pass "VaultStaticSecret 'webapp-static' có spec.type: kv-v2"
else
  fail "VaultStaticSecret 'webapp-static' thiếu hoặc sai spec.type (mong đợi: kv-v2, thực tế: ${VSS_TYPE:-<trống>})"
fi

# --- Kiểm tra 7: Kubernetes Secret 'webapp-static-secret' tồn tại trong namespace app (Bước 2) -
if kubectl get secret webapp-static-secret -n app >/dev/null 2>&1; then
  pass "Kubernetes Secret 'webapp-static-secret' tồn tại trong namespace app"
else
  fail "Kubernetes Secret 'webapp-static-secret' chưa được tạo — kiểm tra VaultStaticSecret và logs VSO"
fi

# --- Kiểm tra 8: Secret 'webapp-static-secret' có dữ liệu (không rỗng) (Bước 2) -
SECRET_DATA=$(kubectl get secret webapp-static-secret -n app \
  -o jsonpath='{.data}' 2>/dev/null)
if [ -n "$SECRET_DATA" ] && [ "$SECRET_DATA" != "{}" ]; then
  pass "Kubernetes Secret 'webapp-static-secret' có dữ liệu (data không rỗng)"
else
  fail "Kubernetes Secret 'webapp-static-secret' không có dữ liệu — VSO chưa đồng bộ thành công"
fi

# --- Kiểm tra 9: Database secrets engine đã được enable tại path db (Bước 3) ------
if vault secrets list 2>/dev/null | grep -q "^db/"; then
  pass "Database secrets engine đã được enable tại path 'db'"
else
  fail "Database secrets engine chưa được enable tại path 'db' — chạy: vault secrets enable -path=db database"
fi

# --- Kiểm tra 10: VaultDynamicSecret 'webapp-dynamic' tồn tại trong namespace app (Bước 3) -
if kubectl get vaultdynamicsecret webapp-dynamic -n app >/dev/null 2>&1; then
  pass "VaultDynamicSecret 'webapp-dynamic' tồn tại trong namespace app"
else
  fail "VaultDynamicSecret 'webapp-dynamic' chưa được tạo trong namespace app"
fi

# --- Kiểm tra 11: VaultDynamicSecret 'webapp-dynamic' có revoke: true (Bước 3) ---
# Kiểm tra field revoke để đảm bảo học viên đặt đúng cho môi trường production.
VDS_REVOKE=$(kubectl get vaultdynamicsecret webapp-dynamic -n app \
  -o jsonpath='{.spec.revoke}' 2>/dev/null)
if [ "$VDS_REVOKE" = "true" ]; then
  pass "VaultDynamicSecret 'webapp-dynamic' có spec.revoke: true"
else
  fail "VaultDynamicSecret 'webapp-dynamic' thiếu spec.revoke: true — cần bật để tránh lease leak trên production"
fi

# --- Kiểm tra 12: Kubernetes Secret 'dynamic-db-creds' tồn tại trong namespace app (Bước 3) -
if kubectl get secret dynamic-db-creds -n app >/dev/null 2>&1; then
  pass "Kubernetes Secret 'dynamic-db-creds' tồn tại trong namespace app"
else
  fail "Kubernetes Secret 'dynamic-db-creds' chưa được tạo — kiểm tra VaultDynamicSecret và logs VSO"
fi

# --- Kiểm tra 13: PKI secrets engine đã được enable (Bước 4) ---------------------
if vault secrets list 2>/dev/null | grep -q "^pki/"; then
  pass "PKI secrets engine đã được enable"
else
  fail "PKI secrets engine chưa được enable — chạy: vault secrets enable pki"
fi

# --- Kiểm tra 14: PKI role 'default' đã được tạo (Bước 4) -----------------------
if vault read pki/roles/default >/dev/null 2>&1; then
  pass "PKI role 'default' tồn tại tại pki/roles/default"
else
  fail "PKI role 'default' chưa được tạo — xem Bước 4 trong README.md"
fi

# --- Kiểm tra 15: VaultPKISecret 'webapp-pki' tồn tại trong namespace app (Bước 4) -
if kubectl get vaultpkisecret webapp-pki -n app >/dev/null 2>&1; then
  pass "VaultPKISecret 'webapp-pki' tồn tại trong namespace app"
else
  fail "VaultPKISecret 'webapp-pki' chưa được tạo trong namespace app"
fi

# --- Kiểm tra 16: Kubernetes Secret 'pki-tls-secret' tồn tại (Bước 4) -----------
if kubectl get secret pki-tls-secret -n app >/dev/null 2>&1; then
  pass "Kubernetes Secret 'pki-tls-secret' tồn tại trong namespace app"
else
  fail "Kubernetes Secret 'pki-tls-secret' chưa được tạo — kiểm tra VaultPKISecret và logs VSO"
fi

# --- Kiểm tra 17: Secret 'pki-tls-secret' có key tls.crt (Bước 4) ---------------
TLS_CRT=$(kubectl get secret pki-tls-secret -n app \
  -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
if [ -n "$TLS_CRT" ]; then
  pass "Kubernetes Secret 'pki-tls-secret' có key tls.crt"
else
  fail "Kubernetes Secret 'pki-tls-secret' thiếu key tls.crt — destination.type phải là kubernetes.io/tls"
fi

# --- Kiểm tra 18: Secret 'pki-tls-secret' có key tls.key (Bước 4) ---------------
TLS_KEY=$(kubectl get secret pki-tls-secret -n app \
  -o jsonpath='{.data.tls\.key}' 2>/dev/null)
if [ -n "$TLS_KEY" ]; then
  pass "Kubernetes Secret 'pki-tls-secret' có key tls.key"
else
  fail "Kubernetes Secret 'pki-tls-secret' thiếu key tls.key — destination.type phải là kubernetes.io/tls"
fi

# --- Kiểm tra 19: Secret 'pki-tls-secret' có type kubernetes.io/tls (Bước 4) ----
TLS_TYPE=$(kubectl get secret pki-tls-secret -n app \
  -o jsonpath='{.type}' 2>/dev/null)
if [ "$TLS_TYPE" = "kubernetes.io/tls" ]; then
  pass "Kubernetes Secret 'pki-tls-secret' có type: kubernetes.io/tls"
else
  fail "Kubernetes Secret 'pki-tls-secret' sai type (mong đợi: kubernetes.io/tls, thực tế: ${TLS_TYPE:-<trống>})"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
