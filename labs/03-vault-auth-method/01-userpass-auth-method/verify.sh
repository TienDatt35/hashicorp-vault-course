#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Userpass Auth Method"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Chạy bộ kiểm tra này SAU KHI hoàn thành bước 1-11 (trước bước 12 disable).
# Exit code 0 chỉ khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Userpass Auth Method"
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

# --- Kiểm tra 1: token auth method có sẵn (bước 1) -------------------------
if vault auth list -format=json 2>/dev/null | grep -q '"token/"'; then
  pass "token/ auth method có sẵn mặc định (không thể disable)"
else
  fail "token/ auth method không tìm thấy trong vault auth list"
fi

# --- Kiểm tra 2: userpass auth method đã được enable (bước 2) ---------------
if vault auth list -format=json 2>/dev/null | grep -q '"userpass/"'; then
  pass "userpass/ auth method đã được enable"
else
  fail "userpass/ auth method chưa được enable — hãy chạy: vault auth enable userpass"
fi

# --- Kiểm tra 3: user alice đã tồn tại (bước 3) ----------------------------
if vault read -format=json auth/userpass/users/alice >/dev/null 2>&1; then
  pass "User alice đã được tạo trong userpass auth method"
else
  fail "User alice chưa tồn tại — hãy chạy: vault write auth/userpass/users/alice password=vault123 policies=default"
fi

# --- Kiểm tra 4: login bằng alice qua CLI trả về token hợp lệ (bước 4) -----
LOGIN_TOKEN=$(vault login -method=userpass -token-only username=alice password=vault123 2>/dev/null)
if [ -n "$LOGIN_TOKEN" ]; then
  pass "Login bằng alice qua CLI thành công — nhận được token"
else
  fail "Login bằng alice qua CLI thất bại — kiểm tra lại password và policy"
fi

# --- Kiểm tra 5: token của alice có policy default (bước 5) ----------------
if [ -n "${LOGIN_TOKEN:-}" ]; then
  ALICE_POLICIES=$(VAULT_TOKEN="$LOGIN_TOKEN" vault token lookup -format=json 2>/dev/null | grep -o '"default"')
  if [ "$ALICE_POLICIES" = '"default"' ]; then
    pass "Token của alice có policy 'default'"
  else
    fail "Token của alice không có policy 'default' — kiểm tra lại lệnh write user"
  fi
else
  fail "Không thể kiểm tra policy vì CLI login thất bại ở bước trước"
fi

# --- Kiểm tra 6: login qua API trả HTTP 200 (bước 7) -----------------------
login_http_code=$(curl -s -o /dev/null -w "%{http_code}" \
  --request POST \
  --data '{"password": "vault123"}' \
  "${VAULT_ADDR}/v1/auth/userpass/login/alice")

if [ "$login_http_code" = "200" ]; then
  pass "Login API POST /v1/auth/userpass/login/alice trả HTTP 200"
else
  fail "Login API trả HTTP $login_http_code (mong đợi 200) — kiểm tra lại password của alice"
fi

# --- Kiểm tra 7: response API chứa auth.client_token hợp lệ (bước 8) ------
alice_api_token=$(curl -s \
  --request POST \
  --data '{"password": "vault123"}' \
  "${VAULT_ADDR}/v1/auth/userpass/login/alice" \
  | jq -r '.auth.client_token // empty')

if [ -n "$alice_api_token" ]; then
  pass "Response API chứa auth.client_token hợp lệ"
else
  fail "Response API không có auth.client_token — kiểm tra lại login credentials"
fi

# --- Kiểm tra 8: token API dùng được để gọi lookup-self (bước 9) -----------
if [ -n "${alice_api_token:-}" ]; then
  lookup_http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Vault-Token: $alice_api_token" \
    "${VAULT_ADDR}/v1/auth/token/lookup-self")

  if [ "$lookup_http_code" = "200" ]; then
    pass "Token alice dùng được để gọi GET /v1/auth/token/lookup-self qua X-Vault-Token"
  else
    fail "Token alice không gọi được lookup-self — trả HTTP $lookup_http_code (mong đợi 200)"
  fi
else
  fail "Bỏ qua kiểm tra lookup-self vì không lấy được token alice từ API"
fi

# --- Kiểm tra 9: gọi không có token trả 403 (bước 10) ---------------------
no_token_code=$(curl -s -o /dev/null -w "%{http_code}" \
  "${VAULT_ADDR}/v1/auth/token/lookup-self")

if [ "$no_token_code" = "403" ]; then
  pass "Gọi API không có token trả HTTP 403 (đúng hành vi bảo mật)"
else
  fail "Gọi API không có token trả HTTP $no_token_code (mong đợi 403)"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
