#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Wildcard và ACL Templating trong Vault Policy"
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

echo "Đang kiểm tra bài thực hành — Wildcard và ACL Templating trong Vault Policy"
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

# --- Kiểm tra 1: Secret apps/dev/webapp tồn tại (Bước 1) --------------------
if vault kv get secret/apps/dev/webapp >/dev/null 2>&1; then
  pass "Secret 'secret/apps/dev/webapp' tồn tại"
else
  fail "Secret 'secret/apps/dev/webapp' chưa được tạo — xem Bước 1"
fi

# --- Kiểm tra 2: Secret apps/prod/webapp tồn tại (Bước 1) -------------------
if vault kv get secret/apps/prod/webapp >/dev/null 2>&1; then
  pass "Secret 'secret/apps/prod/webapp' tồn tại"
else
  fail "Secret 'secret/apps/prod/webapp' chưa được tạo — xem Bước 1"
fi

# --- Kiểm tra 3: Secret apps/dev/db-primary tồn tại (Bước 1) ----------------
if vault kv get secret/apps/dev/db-primary >/dev/null 2>&1; then
  pass "Secret 'secret/apps/dev/db-primary' tồn tại"
else
  fail "Secret 'secret/apps/dev/db-primary' chưa được tạo — xem Bước 1"
fi

# --- Kiểm tra 4: Secret apps/dev/db-replica tồn tại (Bước 1) ----------------
if vault kv get secret/apps/dev/db-replica >/dev/null 2>&1; then
  pass "Secret 'secret/apps/dev/db-replica' tồn tại"
else
  fail "Secret 'secret/apps/dev/db-replica' chưa được tạo — xem Bước 1"
fi

# --- Kiểm tra 5: Policy env-webapp tồn tại (Bước 2) -------------------------
if vault policy read env-webapp >/dev/null 2>&1; then
  pass "Policy 'env-webapp' tồn tại"
else
  fail "Policy 'env-webapp' chưa được tạo — xem Bước 2"
fi

# --- Kiểm tra 6: Policy env-webapp chứa wildcard + (Bước 2) -----------------
ENV_WEBAPP_CONTENT=$(vault policy read env-webapp 2>/dev/null || echo "")
if echo "$ENV_WEBAPP_CONTENT" | grep -qF 'apps/+/webapp'; then
  pass "Policy 'env-webapp' chứa path với wildcard '+'"
else
  fail "Policy 'env-webapp' không có path 'apps/+/webapp' — kiểm tra lại nội dung policy"
fi

# --- Kiểm tra 7: Policy env-webapp có metadata path để list (Bước 2) --------
if echo "$ENV_WEBAPP_CONTENT" | grep -q 'metadata'; then
  pass "Policy 'env-webapp' có rule metadata để hỗ trợ list"
else
  fail "Policy 'env-webapp' thiếu rule cho path 'secret/metadata/...' — cần thêm để hỗ trợ list"
fi

# --- Kiểm tra 8: Policy db-prefix tồn tại (Bước 3) --------------------------
if vault policy read db-prefix >/dev/null 2>&1; then
  pass "Policy 'db-prefix' tồn tại"
else
  fail "Policy 'db-prefix' chưa được tạo — xem Bước 3"
fi

# --- Kiểm tra 9: Policy db-prefix chứa prefix db-* (Bước 3) -----------------
DB_PREFIX_CONTENT=$(vault policy read db-prefix 2>/dev/null || echo "")
if echo "$DB_PREFIX_CONTENT" | grep -q 'db-\*'; then
  pass "Policy 'db-prefix' chứa prefix pattern 'db-*'"
else
  fail "Policy 'db-prefix' không có prefix pattern 'db-*' — kiểm tra lại nội dung policy"
fi

# --- Kiểm tra 10: Policy per-entity tồn tại (Bước 4) ------------------------
if vault policy read per-entity >/dev/null 2>&1; then
  pass "Policy 'per-entity' tồn tại"
else
  fail "Policy 'per-entity' chưa được tạo — xem Bước 4"
fi

# --- Kiểm tra 11: Policy per-entity chứa ACL template variable (Bước 4) -----
PER_ENTITY_CONTENT=$(vault policy read per-entity 2>/dev/null || echo "")
if echo "$PER_ENTITY_CONTENT" | grep -q 'identity.entity'; then
  pass "Policy 'per-entity' chứa ACL template variable 'identity.entity'"
else
  fail "Policy 'per-entity' không có template variable 'identity.entity' — xem lại Bước 4"
fi

# --- Kiểm tra 12: Entity alice-entity tồn tại (Bước 4) ----------------------
if vault read identity/entity/name/alice-entity >/dev/null 2>&1; then
  pass "Entity 'alice-entity' tồn tại"
else
  fail "Entity 'alice-entity' chưa được tạo — xem Bước 4"
fi

# --- Kiểm tra 13: Entity alice-entity có metadata team (Bước 4) --------------
ENTITY_METADATA=$(vault read -format=json identity/entity/name/alice-entity 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('metadata',{}).get('team',''))" 2>/dev/null || echo "")
if [ -n "$ENTITY_METADATA" ]; then
  pass "Entity 'alice-entity' có metadata 'team' được gán"
else
  fail "Entity 'alice-entity' chưa có metadata 'team' — chạy: vault write identity/entity/name/alice-entity metadata=team=platform"
fi

# --- Kiểm tra 14: Userpass auth method được enable (Bước 4) -----------------
if vault auth list 2>/dev/null | grep -q 'userpass'; then
  pass "Auth method 'userpass' đã được enable"
else
  fail "Auth method 'userpass' chưa được enable — chạy: vault auth enable userpass"
fi

# --- Kiểm tra 15: User alice tồn tại trong userpass (Bước 4) ----------------
if vault read auth/userpass/users/alice >/dev/null 2>&1; then
  pass "User 'alice' tồn tại trong userpass auth"
else
  fail "User 'alice' chưa được tạo — chạy: vault write auth/userpass/users/alice password=training"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
