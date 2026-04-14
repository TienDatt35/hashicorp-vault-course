#!/usr/bin/env bash
# verify.sh — kiểm tra đáp án bài thực hành "Xác thực vào Vault bằng API"
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

echo "Đang kiểm tra bài thực hành — Xác thực vào Vault bằng API"
echo

# --- Kiểm tra 0: Vault đang chạy --------------------------------------------
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 1: Userpass auth method đã được enable ------------------------
if vault auth list -format=json 2>/dev/null | jq -e '."userpass/"' >/dev/null 2>&1; then
  pass "Userpass auth method đã được enable"
else
  fail "Userpass auth method chưa được enable — chạy: vault auth enable userpass"
fi

# --- Kiểm tra 2: User alice đã tồn tại --------------------------------------
if vault read -format=json auth/userpass/users/alice >/dev/null 2>&1; then
  pass "User alice đã tồn tại trong userpass"
else
  fail "User alice chưa được tạo — chạy: vault write auth/userpass/users/alice password=vault123 policies=default"
fi

# --- Kiểm tra 3: Login bằng alice qua API trả HTTP 200 ----------------------
login_http_code=$(curl -s -o /dev/null -w "%{http_code}" \
  --request POST \
  --data '{"password": "vault123"}' \
  "${VAULT_ADDR}/v1/auth/userpass/login/alice")

if [ "$login_http_code" = "200" ]; then
  pass "Login API POST /v1/auth/userpass/login/alice trả HTTP 200"
else
  fail "Login API trả HTTP $login_http_code (mong đợi 200) — kiểm tra lại password của alice"
fi

# --- Kiểm tra 4: Response chứa auth.client_token hợp lệ --------------------
alice_token=$(curl -s \
  --request POST \
  --data '{"password": "vault123"}' \
  "${VAULT_ADDR}/v1/auth/userpass/login/alice" \
  | jq -r '.auth.client_token // empty')

if [ -n "$alice_token" ]; then
  pass "Response chứa auth.client_token hợp lệ (có giá trị, không rỗng)"
else
  fail "Response không có auth.client_token — kiểm tra lại login credentials"
fi

# --- Kiểm tra 5: Token alice dùng được để gọi lookup-self -------------------
if [ -n "$alice_token" ]; then
  lookup_http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Vault-Token: $alice_token" \
    "${VAULT_ADDR}/v1/auth/token/lookup-self")

  if [ "$lookup_http_code" = "200" ]; then
    pass "Token alice dùng được để gọi GET /v1/auth/token/lookup-self (HTTP 200)"
  else
    fail "Token alice không gọi được lookup-self — trả HTTP $lookup_http_code (mong đợi 200)"
  fi
else
  fail "Bỏ qua kiểm tra lookup-self vì không lấy được token alice"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
