#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Khám phá Vault qua CLI, UI và HTTP API
#
# Quy ước:
#   pass "mô tả ngắn"  -> in dòng [PASS]
#   fail "mô tả ngắn"  -> in dòng [FAIL] và tăng số lỗi
#
# Chạy bằng: sh verify.sh
# Exit code 0 chỉ khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Khám phá Vault qua CLI, UI và HTTP API"
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

# --- Kiểm tra 2: vault token lookup trả về root token hợp lệ ----------------
TOKEN_TTL=$(vault token lookup -format=json 2>/dev/null \
  | jq -r '.data.ttl' 2>/dev/null || echo "-1")
if [ "$TOKEN_TTL" = "0" ] 2>/dev/null; then
  pass "vault token lookup thành công — root token có ttl=0 (không hết hạn)"
else
  fail "vault token lookup không trả về đúng (ttl của root token phải là 0, hiện: '${TOKEN_TTL}')"
fi

# --- Kiểm tra 3: token capabilities trên kv/data/app/db trả về root ---------
CAPS=$(vault token capabilities kv/data/app/db 2>/dev/null || echo "")
if [ "$CAPS" = "root" ]; then
  pass "vault token capabilities kv/data/app/db trả về 'root'"
else
  fail "vault token capabilities không trả về 'root' (hiện: '${CAPS}')"
fi

# --- Kiểm tra 4: HTTP API — sys/health trả về initialized=true --------------
HEALTH=$(curl -s "$VAULT_ADDR/v1/sys/health" 2>/dev/null \
  | jq -r '.initialized' 2>/dev/null || echo "")
if [ "$HEALTH" = "true" ]; then
  pass "HTTP API: GET /v1/sys/health trả về initialized=true"
else
  fail "HTTP API: GET /v1/sys/health không trả về đúng (initialized='${HEALTH}')"
fi

# --- Kiểm tra 5: HTTP API — đọc secret kv/app/db thành công -----------------
API_USERNAME=$(curl -s \
  -H "X-Vault-Token: root" \
  "$VAULT_ADDR/v1/kv/data/app/db" 2>/dev/null \
  | jq -r '.data.data.username' 2>/dev/null || echo "")
if [ "$API_USERNAME" = "admin" ]; then
  pass "HTTP API: GET /v1/kv/data/app/db trả về username=admin"
else
  fail "HTTP API: không đọc được secret kv/app/db qua API (username='${API_USERNAME}') — đảm bảo đã hoàn thành lab 1"
fi

# --- Kiểm tra 6: HTTP API — token lookup trả về policies chứa root ----------
API_POLICIES=$(curl -s \
  -H "X-Vault-Token: root" \
  --request POST \
  --data '{"token": "root"}' \
  "$VAULT_ADDR/v1/auth/token/lookup" 2>/dev/null \
  | jq -r '.data.policies[]' 2>/dev/null | grep -c "^root$" || echo "0")
if [ "$API_POLICIES" -ge 1 ] 2>/dev/null; then
  pass "HTTP API: POST /v1/auth/token/lookup trả về policy root"
else
  fail "HTTP API: token lookup qua API không trả về policy root"
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
