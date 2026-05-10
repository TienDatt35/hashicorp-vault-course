#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Secret Transformation với VSO
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

echo "Đang kiểm tra bài thực hành — Secret Transformation với VSO"
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
# Bài lab này cần Kubernetes cluster đang hoạt động.
if kubectl cluster-info >/dev/null 2>&1; then
  pass "kubectl có thể kết nối đến Kubernetes cluster"
else
  fail "Không kết nối được đến Kubernetes cluster — kiểm tra Kind hoặc kubeconfig"
  echo
  echo "Nếu dùng Kind, khởi động cluster bằng:"
  echo "  kind create cluster"
  exit 1
fi

# --- Kiểm tra 2: VaultStaticSecret 'webapp-transform' tồn tại trong namespace app ---
# Tương ứng với Bước 2 trong README.md.
if kubectl get vaultstaticsecret webapp-transform -n app >/dev/null 2>&1; then
  pass "VaultStaticSecret 'webapp-transform' tồn tại trong namespace app"
else
  fail "VaultStaticSecret 'webapp-transform' chưa được tạo trong namespace app"
fi

# --- Kiểm tra 3: VaultStaticSecret 'webapp-transform' có cấu hình transformation ---
# Kiểm tra spec.destination.transformation không rỗng.
TRANSFORM_CHECK=$(kubectl get vaultstaticsecret webapp-transform -n app \
  -o jsonpath='{.spec.destination.transformation}' 2>/dev/null)
if [ -n "$TRANSFORM_CHECK" ] && [ "$TRANSFORM_CHECK" != "{}" ] && [ "$TRANSFORM_CHECK" != "null" ]; then
  pass "VaultStaticSecret 'webapp-transform' có cấu hình transformation"
else
  fail "VaultStaticSecret 'webapp-transform' thiếu cấu hình transformation trong spec.destination.transformation"
fi

# --- Kiểm tra 4: K8s Secret 'webapp-transformed' tồn tại trong namespace app ------
# Tương ứng với Bước 3 trong README.md — VSO phải đã tạo Secret này.
if kubectl get secret webapp-transformed -n app >/dev/null 2>&1; then
  pass "Kubernetes Secret 'webapp-transformed' tồn tại trong namespace app"
else
  fail "Kubernetes Secret 'webapp-transformed' chưa được tạo — kiểm tra VaultStaticSecret và logs VSO"
fi

# --- Kiểm tra 5: K8s Secret 'webapp-transformed' có key 'APP_USER' ----------------
# Tương ứng với Bước 3: key gốc 'username' phải được đổi thành 'APP_USER'.
APP_USER=$(kubectl get secret webapp-transformed -n app \
  -o jsonpath='{.data.APP_USER}' 2>/dev/null)
if [ -n "$APP_USER" ]; then
  pass "Kubernetes Secret 'webapp-transformed' có key 'APP_USER' (tên key đã được đổi)"
else
  fail "Kubernetes Secret 'webapp-transformed' thiếu key 'APP_USER' — kiểm tra templates trong transformation"
fi

# --- Kiểm tra 6: K8s Secret 'webapp-transformed' có key 'APP_PASS' ----------------
# Tương ứng với Bước 3: key gốc 'password' phải được đổi thành 'APP_PASS'.
APP_PASS=$(kubectl get secret webapp-transformed -n app \
  -o jsonpath='{.data.APP_PASS}' 2>/dev/null)
if [ -n "$APP_PASS" ]; then
  pass "Kubernetes Secret 'webapp-transformed' có key 'APP_PASS' (tên key đã được đổi)"
else
  fail "Kubernetes Secret 'webapp-transformed' thiếu key 'APP_PASS' — kiểm tra templates trong transformation"
fi

# --- Kiểm tra 7: K8s Secret 'webapp-transformed' KHÔNG có key 'username' gốc ------
# Tương ứng với Bước 3: excludes phải đã loại bỏ key gốc 'username'.
USERNAME_RAW=$(kubectl get secret webapp-transformed -n app \
  -o jsonpath='{.data.username}' 2>/dev/null)
if [ -z "$USERNAME_RAW" ]; then
  pass "Kubernetes Secret 'webapp-transformed' không có key 'username' gốc (đã bị exclude)"
else
  fail "Kubernetes Secret 'webapp-transformed' vẫn còn key 'username' gốc — cần thêm excludes: ['username|password']"
fi

# --- Kiểm tra 8: K8s Secret 'webapp-transformed' KHÔNG có key 'password' gốc ------
# Tương ứng với Bước 3: excludes phải đã loại bỏ key gốc 'password'.
PASSWORD_RAW=$(kubectl get secret webapp-transformed -n app \
  -o jsonpath='{.data.password}' 2>/dev/null)
if [ -z "$PASSWORD_RAW" ]; then
  pass "Kubernetes Secret 'webapp-transformed' không có key 'password' gốc (đã bị exclude)"
else
  fail "Kubernetes Secret 'webapp-transformed' vẫn còn key 'password' gốc — cần thêm excludes: ['username|password']"
fi

# --- Kiểm tra 9: VaultStaticSecret 'webapp-reshape' tồn tại trong namespace app ----
# Tương ứng với Bước 4 trong README.md.
if kubectl get vaultstaticsecret webapp-reshape -n app >/dev/null 2>&1; then
  pass "VaultStaticSecret 'webapp-reshape' tồn tại trong namespace app"
else
  fail "VaultStaticSecret 'webapp-reshape' chưa được tạo trong namespace app"
fi

# --- Kiểm tra 10: K8s Secret 'webapp-reshaped' có key 'DATABASE_URL' --------------
# Tương ứng với Bước 4: transformation phải tổng hợp thành DATABASE_URL.
DATABASE_URL=$(kubectl get secret webapp-reshaped -n app \
  -o jsonpath='{.data.DATABASE_URL}' 2>/dev/null)
if [ -n "$DATABASE_URL" ]; then
  pass "Kubernetes Secret 'webapp-reshaped' có key 'DATABASE_URL' (reshape thành công)"
else
  fail "Kubernetes Secret 'webapp-reshaped' thiếu key 'DATABASE_URL' — kiểm tra transformation templates trong webapp-reshape"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
