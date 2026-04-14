#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Capabilities trong Vault Policy"
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

echo "Đang kiểm tra bài thực hành — Capabilities trong Vault Policy"
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

# --- Kiểm tra 1: Secret apps/webapp/api tồn tại (Bước 1) -------------------
if vault kv get secret/apps/webapp/api >/dev/null 2>&1; then
  pass "Secret 'secret/apps/webapp/api' tồn tại"
else
  fail "Secret 'secret/apps/webapp/api' chưa được tạo — chạy: vault kv put secret/apps/webapp/api url=http://api:8080"
fi

# --- Kiểm tra 2: Secret apps/webapp/db tồn tại (Bước 1) --------------------
if vault kv get secret/apps/webapp/db >/dev/null 2>&1; then
  pass "Secret 'secret/apps/webapp/db' tồn tại"
else
  fail "Secret 'secret/apps/webapp/db' chưa được tạo — chạy: vault kv put secret/apps/webapp/db host=db:5432"
fi

# --- Kiểm tra 3: Secret apps/webapp/super-secret tồn tại (Bước 1) ----------
if vault kv get secret/apps/webapp/super-secret >/dev/null 2>&1; then
  pass "Secret 'secret/apps/webapp/super-secret' tồn tại"
else
  fail "Secret 'secret/apps/webapp/super-secret' chưa được tạo — chạy: vault kv put secret/apps/webapp/super-secret password=P@ssw0rd"
fi

# --- Kiểm tra 4: Policy webapp-wildcard tồn tại (Bước 2) -------------------
if vault policy read webapp-wildcard >/dev/null 2>&1; then
  pass "Policy 'webapp-wildcard' tồn tại"
else
  fail "Policy 'webapp-wildcard' chưa được tạo — xem solution.md Bước 2"
fi

# --- Kiểm tra 5: webapp-wildcard chứa data/ path và read (Bước 2) -----------
WILDCARD_CONTENT=$(vault policy read webapp-wildcard 2>/dev/null || echo "")
if echo "$WILDCARD_CONTENT" | grep -q 'secret/data/apps/webapp'; then
  pass "Policy 'webapp-wildcard' chứa path 'secret/data/apps/webapp/*'"
else
  fail "Policy 'webapp-wildcard' không có path 'secret/data/apps/webapp/*'"
fi

# --- Kiểm tra 6: Policy webapp-full tồn tại (Bước 3) -----------------------
if vault policy read webapp-full >/dev/null 2>&1; then
  pass "Policy 'webapp-full' tồn tại"
else
  fail "Policy 'webapp-full' chưa được tạo — xem solution.md Bước 3"
fi

# --- Kiểm tra 7: webapp-full chứa metadata/ path (Bước 3) ------------------
FULL_CONTENT=$(vault policy read webapp-full 2>/dev/null || echo "")
if echo "$FULL_CONTENT" | grep -q 'metadata'; then
  pass "Policy 'webapp-full' chứa path 'metadata/' để hỗ trợ list"
else
  fail "Policy 'webapp-full' không có path 'metadata/' — cần thêm rule cho secret/metadata/apps/webapp/*"
fi

# --- Kiểm tra 8: webapp-full có capability list (Bước 3) -------------------
if echo "$FULL_CONTENT" | grep -q '"list"'; then
  pass "Policy 'webapp-full' có capability 'list'"
else
  fail "Policy 'webapp-full' không có capability 'list' trong rule metadata"
fi

# --- Kiểm tra 9: Policy webapp-deny-secret tồn tại (Bước 4) ----------------
if vault policy read webapp-deny-secret >/dev/null 2>&1; then
  pass "Policy 'webapp-deny-secret' tồn tại"
else
  fail "Policy 'webapp-deny-secret' chưa được tạo — xem solution.md Bước 4"
fi

# --- Kiểm tra 10: webapp-deny-secret chứa "deny" (Bước 4) ------------------
DENY_CONTENT=$(vault policy read webapp-deny-secret 2>/dev/null || echo "")
if echo "$DENY_CONTENT" | grep -q '"deny"'; then
  pass "Policy 'webapp-deny-secret' chứa capability 'deny'"
else
  fail "Policy 'webapp-deny-secret' không có capability 'deny' — kiểm tra lại nội dung policy"
fi

# --- Kiểm tra 11: webapp-deny-secret chặn path super-secret (Bước 4) -------
if echo "$DENY_CONTENT" | grep -q 'super-secret'; then
  pass "Policy 'webapp-deny-secret' có rule cho path 'super-secret'"
else
  fail "Policy 'webapp-deny-secret' không có rule cho path 'super-secret'"
fi

# --- Kiểm tra 12: Ba policies có trong vault policy list --------------------
POLICY_LIST=$(vault policy list 2>/dev/null || echo "")

if echo "$POLICY_LIST" | grep -q 'webapp-wildcard'; then
  pass "'vault policy list' hiển thị 'webapp-wildcard'"
else
  fail "'vault policy list' không có 'webapp-wildcard'"
fi

if echo "$POLICY_LIST" | grep -q 'webapp-full'; then
  pass "'vault policy list' hiển thị 'webapp-full'"
else
  fail "'vault policy list' không có 'webapp-full'"
fi

if echo "$POLICY_LIST" | grep -q 'webapp-deny-secret'; then
  pass "'vault policy list' hiển thị 'webapp-deny-secret'"
else
  fail "'vault policy list' không có 'webapp-deny-secret'"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
