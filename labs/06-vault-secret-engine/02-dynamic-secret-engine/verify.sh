#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Dynamic Secrets Engine
#
# Script kiểm tra:
#   0. Vault có thể truy cập
#   1. Database engine được enable tại path "database/"
#   2. Config "mydb" tồn tại trong database/config/
#   3. Role "db-readonly" tồn tại và có default_ttl đúng
#   4. Policy "db-client" tồn tại trong Vault

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Dynamic Secrets Engine"
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

# --- Kiểm tra 1: Database engine tồn tại tại path "database/" ---------------
if vault secrets list -format=json 2>/dev/null | grep -q '"database/"'; then
  pass "Database secrets engine đã được enable tại path 'database/'"
else
  fail "Không tìm thấy 'database/' — hãy chạy: vault secrets enable database"
fi

# --- Kiểm tra 2: Config "mydb" tồn tại trong database/config/ ---------------
if vault list database/config 2>/dev/null | grep -q 'mydb'; then
  pass "Config 'mydb' tồn tại trong database/config/"
else
  fail "Không tìm thấy config 'mydb' — hãy chạy: vault write database/config/mydb plugin_name=postgresql-database-plugin ..."
fi

# --- Kiểm tra 3: Role "db-readonly" tồn tại trong database/roles/ -----------
if vault list database/roles 2>/dev/null | grep -q 'db-readonly'; then
  pass "Role 'db-readonly' tồn tại trong database/roles/"
else
  fail "Không tìm thấy role 'db-readonly' — hãy chạy: vault write database/roles/db-readonly db_name=mydb ..."
fi

# --- Kiểm tra 4: Role "db-readonly" có default_ttl là 3600 giây (1h) -------
default_ttl=$(vault read -format=json database/roles/db-readonly 2>/dev/null \
  | jq -r '.data.default_ttl // "0"' 2>/dev/null || echo "0")
if [ "$default_ttl" = "3600" ]; then
  pass "Role 'db-readonly' có default_ttl=3600 giây (1h) đúng như yêu cầu"
else
  fail "default_ttl của role 'db-readonly' không đúng (nhận được: ${default_ttl}s, cần: 3600s) — hãy kiểm tra lại tham số default_ttl=1h"
fi

# --- Kiểm tra 5: Policy "db-client" tồn tại trong Vault --------------------
if vault policy list 2>/dev/null | grep -q 'db-client'; then
  pass "Policy 'db-client' tồn tại trong Vault"
else
  fail "Không tìm thấy policy 'db-client' — hãy chạy: vault policy write db-client /tmp/db-client-policy.hcl"
fi

# --- Kiểm tra 6: Policy "db-client" chứa path database/creds/db-readonly ----
policy_content=$(vault policy read db-client 2>/dev/null || echo "")
if echo "$policy_content" | grep -q 'database/creds/db-readonly'; then
  pass "Policy 'db-client' chứa path 'database/creds/db-readonly' đúng như yêu cầu"
else
  fail "Policy 'db-client' không chứa path 'database/creds/db-readonly' — hãy kiểm tra lại nội dung policy"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
