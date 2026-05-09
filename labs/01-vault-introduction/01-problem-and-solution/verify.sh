#!/usr/bin/env bash
# verify.sh — kiểm tra đáp án cho bài thực hành
# "Khám phá Vault dev server và token cơ bản"
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

echo "Đang kiểm tra bài thực hành — Khám phá Vault dev server và token cơ bản"
echo

# --- Kiểm tra 1: Vault đang chạy -------------------------------------------
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 2: Root token hợp lệ ------------------------------------------
TOKEN_TYPE=$(vault token lookup -format=json 2>/dev/null \
  | jq -r '.data.policies[]' 2>/dev/null | grep -c "^root$" || echo "0")
if [ "$TOKEN_TYPE" -ge 1 ] 2>/dev/null; then
  pass "Xác thực thành công bằng root token (policy root có mặt)"
else
  fail "Token hiện tại không có policy root (chạy: vault login root)"
fi

# --- Kiểm tra 3: secrets list trả về ít nhất các engine mặc định ------------
# Trong dev mode, các engine mặc định là: cubbyhole/, identity/, secret/, sys/
SECRETS_COUNT=$(vault secrets list -format=json 2>/dev/null \
  | jq 'keys | length' 2>/dev/null || echo "0")
if [ "$SECRETS_COUNT" -ge 4 ] 2>/dev/null; then
  pass "Danh sách secrets engine trả về đủ (${SECRETS_COUNT} engine)"
else
  fail "Không đọc được danh sách secrets engine (chạy: vault secrets list)"
fi

# --- Kiểm tra 4: auth list trả về ít nhất token/ ----------------------------
if vault auth list -format=json 2>/dev/null \
    | jq -e '.["token/"].type == "token"' >/dev/null 2>&1; then
  pass "Danh sách auth method trả về và có token/ mặc định"
else
  fail "Không đọc được danh sách auth method (chạy: vault auth list)"
fi

# --- Kiểm tra 5: KV v2 đã mount tại path kv/ --------------------------------
if vault secrets list -format=json 2>/dev/null \
    | jq -e '.["kv/"].type == "kv" and .["kv/"].options.version == "2"' >/dev/null 2>&1; then
  pass "KV v2 đã mount tại path kv/"
else
  fail "KV v2 chưa mount tại path kv/ (chạy: vault secrets enable -version=2 kv)"
fi

# --- Kiểm tra 6: secret kv/app/db tồn tại với dữ liệu đúng ------------------
DB_USERNAME=$(vault kv get -format=json kv/app/db 2>/dev/null \
  | jq -r '.data.data.username' 2>/dev/null || echo "")
DB_PASSWORD=$(vault kv get -format=json kv/app/db 2>/dev/null \
  | jq -r '.data.data.password' 2>/dev/null || echo "")
if [ "$DB_USERNAME" = "admin" ] && [ "$DB_PASSWORD" = "s3cret-v1" ]; then
  pass "Secret kv/app/db tồn tại với username=admin và password=s3cret-v1"
else
  fail "Secret kv/app/db chưa đúng (mong đợi username=admin, password=s3cret-v1; hiện: username='${DB_USERNAME}', password='${DB_PASSWORD}')"
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
