#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "So sánh Static Auth: AppRole vs Userpass"
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

echo "Đang kiểm tra bài thực hành — So sánh Static Auth: AppRole vs Userpass"
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

# --- Kiểm tra 1: Policy "dev-policy" tồn tại (Bước 1) ----------------------
if vault policy read dev-policy >/dev/null 2>&1; then
  pass "Policy 'dev-policy' tồn tại"
else
  fail "Policy 'dev-policy' chưa được tạo"
fi

# --- Kiểm tra 2: AppRole auth được enable (Bước 2) --------------------------
if vault auth list -format=json 2>/dev/null | jq -e '."approle/"' >/dev/null 2>&1; then
  pass "Auth method approle được enable"
else
  fail "Auth method approle chưa được enable"
fi

# --- Kiểm tra 3: Role "dev-role" tồn tại trong AppRole (Bước 2) -------------
if vault read auth/approle/role/dev-role >/dev/null 2>&1; then
  pass "AppRole role 'dev-role' tồn tại"
else
  fail "AppRole role 'dev-role' chưa được tạo"
fi

# --- Kiểm tra 4: Role "dev-role" có policy "dev-policy" (Bước 2) -----------
DEV_ROLE_POLICIES=$(vault read -format=json auth/approle/role/dev-role 2>/dev/null \
  | jq -r '.data.token_policies // [] | join(",")' 2>/dev/null || echo "")

if echo "$DEV_ROLE_POLICIES" | grep -q "dev-policy"; then
  pass "Role 'dev-role' có policy 'dev-policy'"
else
  fail "Role 'dev-role' chưa được gán policy 'dev-policy' (hiện có: ${DEV_ROLE_POLICIES:-không có})"
fi

# --- Kiểm tra 5: Userpass auth được enable (Bước 3) -------------------------
if vault auth list -format=json 2>/dev/null | jq -e '."userpass/"' >/dev/null 2>&1; then
  pass "Auth method userpass được enable"
else
  fail "Auth method userpass chưa được enable"
fi

# --- Kiểm tra 6: User "alice" tồn tại trên userpass (Bước 3) ---------------
if vault read auth/userpass/users/alice >/dev/null 2>&1; then
  pass "User 'alice' tồn tại trên userpass"
else
  fail "User 'alice' chưa được tạo trên userpass"
fi

# --- Kiểm tra 7: User "alice" có policy "dev-policy" (Bước 3) ---------------
ALICE_POLICIES=$(vault read -format=json auth/userpass/users/alice 2>/dev/null \
  | jq -r '.data.token_policies // [] | join(",")' 2>/dev/null || echo "")

if echo "$ALICE_POLICIES" | grep -q "dev-policy"; then
  pass "User 'alice' có policy 'dev-policy'"
else
  fail "User 'alice' chưa được gán policy 'dev-policy' (hiện có: ${ALICE_POLICIES:-không có})"
fi

# --- Kiểm tra 8: Alice có thể đăng nhập bằng userpass (Bước 3/5) -----------
ALICE_TOKEN=$(vault write -format=json auth/userpass/login/alice \
  password="training" 2>/dev/null \
  | jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -n "$ALICE_TOKEN" ] && [ "$ALICE_TOKEN" != "null" ]; then
  pass "User 'alice' có thể đăng nhập qua userpass"

  # --- Kiểm tra 9: Token của alice có capabilities đọc secret/data/dev -------
  ALICE_CAPS=$(VAULT_TOKEN="$ALICE_TOKEN" vault token capabilities secret/data/dev 2>/dev/null || echo "")
  if echo "$ALICE_CAPS" | grep -q "read"; then
    pass "Token của 'alice' có quyền đọc 'secret/data/dev' (policy 'dev-policy' hoạt động)"
  else
    fail "Token của 'alice' không có quyền đọc 'secret/data/dev' — kiểm tra policy 'dev-policy' và gán cho user 'alice'"
  fi
else
  fail "Không thể đăng nhập bằng user 'alice' — kiểm tra user đã tạo và password là 'training'"
  # Bỏ qua kiểm tra 9 nếu login thất bại
  fail "Bỏ qua kiểm tra capabilities — đăng nhập alice thất bại"
fi

# --- Kiểm tra 10: Role "dev-role" có secret_id_ttl được cấu hình (Bước 2) --
DEV_ROLE_SIDTTL=$(vault read -format=json auth/approle/role/dev-role 2>/dev/null \
  | jq -r '.data.secret_id_ttl' 2>/dev/null || echo "0")

if [ "${DEV_ROLE_SIDTTL:-0}" != "0" ]; then
  pass "Role 'dev-role' có secret_id_ttl được cấu hình (${DEV_ROLE_SIDTTL}s)"
else
  fail "Role 'dev-role' chưa cấu hình secret_id_ttl — đặt giá trị 24h khi tạo role"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
