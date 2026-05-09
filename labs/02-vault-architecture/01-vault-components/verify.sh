#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Khám phá kiến trúc Vault: thành phần và path-based routing"
#
# Quy ước:
#   pass "mô tả ngắn"  -> in dòng [PASS]
#   fail "mô tả ngắn"  -> in dòng [FAIL] và tăng số lỗi
#
# Chạy bằng: bash verify.sh
# Exit code 0 chỉ khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Kiến trúc Vault: thành phần và path-based routing"
echo

# --- Kiểm tra 1: Vault đang chạy -------------------------------------------
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo "  Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 2: vault secrets list trả về ít nhất 4 engine mặc định --------
SECRETS_COUNT=$(vault secrets list -format=json 2>/dev/null | jq 'keys | length' 2>/dev/null || echo "0")
if [ "$SECRETS_COUNT" -ge 4 ] 2>/dev/null; then
  pass "vault secrets list trả về $SECRETS_COUNT engine (bao gồm các engine mặc định)"
else
  fail "vault secrets list không trả về đủ engine mặc định (đếm được: ${SECRETS_COUNT})"
fi

# --- Kiểm tra 3: vault auth list có token/ mặc định -------------------------
if vault auth list -format=json 2>/dev/null | jq -e '.["token/"].type == "token"' >/dev/null 2>&1; then
  pass "vault auth list có token/ — auth method mặc định không thể disable"
else
  fail "vault auth list không có token/ (không mong đợi — hãy kiểm tra vault auth list thủ công)"
fi

# --- Kiểm tra 4: sys/mounts trả về cùng dữ liệu với secrets list ------------
SYS_COUNT=$(vault read -format=json sys/mounts 2>/dev/null | jq '.data | keys | length' 2>/dev/null || echo "0")
if [ "$SYS_COUNT" -ge 4 ] 2>/dev/null; then
  pass "vault read sys/mounts trả về $SYS_COUNT mounts — System Backend hoạt động"
else
  fail "vault read sys/mounts không trả về đủ dữ liệu (đếm được: ${SYS_COUNT})"
fi

# --- Kiểm tra 5: KV v2 đã mount tại custom path app/ -----------------------
if vault secrets list -format=json 2>/dev/null | jq -e '.["app/"].type == "kv" and .["app/"].options.version == "2"' >/dev/null 2>&1; then
  pass "KV v2 đã mount tại custom path app/"
else
  fail "KV v2 chưa mount tại path app/ (chạy: vault secrets enable -version=2 -path=app kv)"
fi

# --- Kiểm tra 6: KV v2 đã mount tại custom path config/ --------------------
if vault secrets list -format=json 2>/dev/null | jq -e '.["config/"].type == "kv" and .["config/"].options.version == "2"' >/dev/null 2>&1; then
  pass "KV v2 đã mount tại custom path config/"
else
  fail "KV v2 chưa mount tại path config/ (chạy: vault secrets enable -version=2 -path=config kv)"
fi

# --- Kiểm tra 7: secret app/database tồn tại với đúng dữ liệu ---------------
APP_SECRET=$(vault kv get -format=json app/database 2>/dev/null | jq -r '.data.data.password' 2>/dev/null || echo "")
if [ "$APP_SECRET" = "db-secret" ]; then
  pass "Secret app/database tồn tại với password=db-secret"
else
  fail "Secret app/database chưa đúng (mong đợi password=db-secret, hiện: '${APP_SECRET}')"
fi

# --- Kiểm tra 8: secret config/feature-flags tồn tại -------------------------
CONFIG_SECRET=$(vault kv get -format=json config/feature-flags 2>/dev/null | jq -r '.data.data.debug' 2>/dev/null || echo "")
if [ "$CONFIG_SECRET" = "true" ]; then
  pass "Secret config/feature-flags tồn tại với debug=true"
else
  fail "Secret config/feature-flags chưa đúng (mong đợi debug=true, hiện: '${CONFIG_SECRET}')"
fi

# --- Kiểm tra 9: auth method userpass đã enable -----------------------------
if vault auth list -format=json 2>/dev/null | jq -e '.["userpass/"].type == "userpass"' >/dev/null 2>&1; then
  pass "Auth method userpass đã được enable tại auth/userpass/"
else
  fail "Auth method userpass chưa enable (chạy: vault auth enable userpass)"
fi

# --- Kiểm tra 10: user student tồn tại trong userpass -----------------------
if vault read auth/userpass/users/student >/dev/null 2>&1; then
  pass "User student tồn tại trong auth/userpass"
else
  fail "User student chưa được tạo (chạy: vault write auth/userpass/users/student password=student-pass policies=default)"
fi

# ---------------------------------------------------------------------------
echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
