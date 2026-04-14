#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Giới thiệu Vault Policies"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Chạy: bash verify.sh

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Giới thiệu Vault Policies"
echo

# --- Kiểm tra 0: Vault đang chạy -------------------------------------------
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 1: Policy "dev-readonly" tồn tại (Bước 1) --------------------
if vault policy read dev-readonly >/dev/null 2>&1; then
  pass "Policy 'dev-readonly' tồn tại"
else
  fail "Policy 'dev-readonly' chưa được tạo — chạy: vault policy write dev-readonly dev-readonly.hcl"
fi

# --- Kiểm tra 2: Policy "ops-admin" tồn tại (Bước 2) -----------------------
if vault policy read ops-admin >/dev/null 2>&1; then
  pass "Policy 'ops-admin' tồn tại"
else
  fail "Policy 'ops-admin' chưa được tạo — chạy: vault policy write ops-admin ops-admin.hcl"
fi

# --- Kiểm tra 3: "dev-readonly" chứa capability "read" (Bước 1) ------------
DEV_READONLY_CONTENT=$(vault policy read dev-readonly 2>/dev/null || echo "")
if echo "$DEV_READONLY_CONTENT" | grep -q '"read"'; then
  pass "Policy 'dev-readonly' chứa capability 'read'"
else
  fail "Policy 'dev-readonly' không chứa capability 'read' — kiểm tra nội dung file dev-readonly.hcl"
fi

# --- Kiểm tra 4: "dev-readonly" chứa capability "list" (Bước 1) ------------
if echo "$DEV_READONLY_CONTENT" | grep -q '"list"'; then
  pass "Policy 'dev-readonly' chứa capability 'list'"
else
  fail "Policy 'dev-readonly' không chứa capability 'list' — kiểm tra nội dung file dev-readonly.hcl"
fi

# --- Kiểm tra 5: "ops-admin" chứa "deny" (Bước 2) --------------------------
OPS_ADMIN_CONTENT=$(vault policy read ops-admin 2>/dev/null || echo "")
if echo "$OPS_ADMIN_CONTENT" | grep -q '"deny"'; then
  pass "Policy 'ops-admin' chứa explicit deny"
else
  fail "Policy 'ops-admin' không chứa 'deny' — thêm explicit deny cho path 'secret/data/ops/prod-password'"
fi

# --- Kiểm tra 6: "vault policy list" có cả hai policies (Bước 5) -----------
POLICY_LIST=$(vault policy list 2>/dev/null || echo "")

if echo "$POLICY_LIST" | grep -q "dev-readonly"; then
  pass "'vault policy list' hiển thị 'dev-readonly'"
else
  fail "'vault policy list' không có 'dev-readonly'"
fi

if echo "$POLICY_LIST" | grep -q "ops-admin"; then
  pass "'vault policy list' hiển thị 'ops-admin'"
else
  fail "'vault policy list' không có 'ops-admin'"
fi

# --- Kiểm tra 7: "dev-readonly" áp dụng đúng path (Bước 1) -----------------
# Kiểm tra path "secret/data/dev/*" có trong policy
if echo "$DEV_READONLY_CONTENT" | grep -q 'secret/data/dev/'; then
  pass "Policy 'dev-readonly' bảo vệ đúng path 'secret/data/dev/*'"
else
  fail "Policy 'dev-readonly' không có rule cho path 'secret/data/dev/*'"
fi

# --- Kiểm tra 8: "ops-admin" áp dụng đúng path cho ops (Bước 2) ------------
if echo "$OPS_ADMIN_CONTENT" | grep -q 'secret/data/ops/'; then
  pass "Policy 'ops-admin' bảo vệ đúng path 'secret/data/ops/*'"
else
  fail "Policy 'ops-admin' không có rule cho path 'secret/data/ops/*'"
fi

# --- Kiểm tra 9: "ops-admin" có explicit deny trên path prod-password -------
if echo "$OPS_ADMIN_CONTENT" | grep -q 'prod-password'; then
  pass "Policy 'ops-admin' có rule riêng cho path 'prod-password'"
else
  fail "Policy 'ops-admin' không có rule riêng cho 'prod-password' — thêm explicit deny cho path đó"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
