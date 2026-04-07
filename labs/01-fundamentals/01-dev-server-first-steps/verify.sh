#!/usr/bin/env bash
# Verifies that the learner has:
#   1. A running, unsealed dev Vault server
#   2. The kv-v2 secrets engine mounted at "secret/" (default in dev mode)
#   3. A secret at secret/hello with key "message" = "world"
set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra Bài 1.1 — Vault dev server đầu tiên của bạn"
echo

# 1. Server có thể truy cập và đã unseal.
status_json=$(vault status -format=json 2>/dev/null || echo '{}')
if [ -z "$status_json" ] || ! echo "$status_json" | jq -e . >/dev/null 2>&1; then
  fail "Không truy cập được Vault tại $VAULT_ADDR — bạn đã chạy 'make setup' chưa?"
else
  if [ "$(echo "$status_json" | jq -r '.sealed')" = "false" ]; then
    pass "Vault có thể truy cập và đã unseal"
  else
    fail "Vault đang ở trạng thái sealed"
  fi
fi

# 2. KV v2 được mount tại secret/.
mounts_json=$(vault read -format=json sys/mounts 2>/dev/null || echo '{}')
if echo "$mounts_json" | jq -e '.data["secret/"] | select(.type=="kv") | select(.options.version=="2")' >/dev/null 2>&1; then
  pass "kv-v2 secrets engine được mount tại secret/"
else
  fail "kv-v2 chưa được mount tại secret/ (dev mode đáng lẽ tự tạo sẵn)"
fi

# 3. secret/hello có message=world.
secret_json=$(vault kv get -format=json secret/hello 2>/dev/null || echo '{}')
msg=$(echo "$secret_json" | jq -r '.data.data.message // empty')
if [ "$msg" = "world" ]; then
  pass "secret/hello chứa message=world"
else
  fail "secret/hello chưa có message=world (giá trị hiện tại: '${msg:-<chưa có>}'). Thử: vault kv put secret/hello message=world"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
