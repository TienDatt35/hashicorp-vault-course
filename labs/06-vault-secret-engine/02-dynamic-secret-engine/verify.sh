#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Dynamic Secrets Engine
#
# Chạy bằng: sh verify.sh

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

# --- Kiểm tra 1: PostgreSQL container đang chạy (Bước 0) --------------------
if docker exec postgres-lab pg_isready -U vault-admin >/dev/null 2>&1; then
  pass "PostgreSQL đang chạy trong container 'postgres-lab'"
else
  fail "PostgreSQL chưa chạy — hãy khởi động bằng lệnh:"
  printf '       docker run -d --name postgres-lab \\\n'
  printf '         -e POSTGRES_USER=vault-admin \\\n'
  printf '         -e POSTGRES_PASSWORD=admin-password \\\n'
  printf '         -e POSTGRES_DB=mydb \\\n'
  printf '         -p 5432:5432 postgres:15-alpine\n'
fi

# --- Kiểm tra 2: Database engine tồn tại tại path "database/" ---------------
if vault secrets list -format=json 2>/dev/null | grep -q '"database/"'; then
  pass "Database secrets engine đã được enable tại path 'database/'"
else
  fail "Không tìm thấy 'database/' — hãy chạy: vault secrets enable database"
fi

# --- Kiểm tra 3: Config "mydb" tồn tại trong database/config/ ---------------
if vault list database/config 2>/dev/null | grep -q 'mydb'; then
  pass "Config 'mydb' tồn tại trong database/config/"
else
  fail "Không tìm thấy config 'mydb' — hãy chạy: vault write database/config/mydb ..."
fi

# --- Kiểm tra 4: Role "db-readonly" tồn tại trong database/roles/ -----------
if vault list database/roles 2>/dev/null | grep -q 'db-readonly'; then
  pass "Role 'db-readonly' tồn tại trong database/roles/"
else
  fail "Không tìm thấy role 'db-readonly' — hãy chạy: vault write database/roles/db-readonly ..."
fi

# --- Kiểm tra 5: Role "db-readonly" có default_ttl là 3600 giây (1h) -------
default_ttl=$(vault read -format=json database/roles/db-readonly 2>/dev/null \
  | jq -r '.data.default_ttl // "0"' 2>/dev/null || echo "0")
if [ "$default_ttl" = "3600" ]; then
  pass "Role 'db-readonly' có default_ttl=3600 giây (1h)"
else
  fail "default_ttl không đúng (nhận được: ${default_ttl}s, cần: 3600s)"
fi

# --- Kiểm tra 6: Policy "db-client" tồn tại và đúng nội dung ---------------
if vault policy list 2>/dev/null | grep -q 'db-client'; then
  pass "Policy 'db-client' tồn tại trong Vault"
else
  fail "Không tìm thấy policy 'db-client' — hãy chạy: vault policy write db-client ..."
fi

policy_content=$(vault policy read db-client 2>/dev/null || echo "")
if echo "$policy_content" | grep -q 'database/creds/db-readonly'; then
  pass "Policy 'db-client' chứa path 'database/creds/db-readonly'"
else
  fail "Policy 'db-client' không chứa path 'database/creds/db-readonly'"
fi

# --- Kiểm tra 7: Vault tạo được credential thật từ PostgreSQL (Bước 6) -----
CREDS=$(vault read -format=json database/creds/db-readonly 2>/dev/null || echo "")
DB_USER=$(echo "$CREDS" | jq -r '.data.username // ""' 2>/dev/null || echo "")
DB_PASS=$(echo "$CREDS" | jq -r '.data.password // ""' 2>/dev/null || echo "")
LEASE_ID=$(echo "$CREDS" | jq -r '.lease_id // ""' 2>/dev/null || echo "")

if [ -n "$DB_USER" ] && [ -n "$DB_PASS" ]; then
  pass "Vault tạo credential thật thành công (username: $DB_USER)"
  # Revoke ngay để giữ môi trường sạch
  [ -n "$LEASE_ID" ] && vault lease revoke "$LEASE_ID" >/dev/null 2>&1 || true
else
  fail "Không tạo được credential — kiểm tra kết nối PostgreSQL và cấu hình Vault"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
