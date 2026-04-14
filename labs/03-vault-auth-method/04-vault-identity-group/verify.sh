#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Vault Identity Groups: Internal và External"
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

echo "Đang kiểm tra bài thực hành — Vault Identity Groups"
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

# --- Kiểm tra 1: Policy "dev" tồn tại ----------------------------------------
if vault policy read dev >/dev/null 2>&1; then
  pass "Policy 'dev' tồn tại"
else
  fail "Policy 'dev' chưa được tạo"
fi

# --- Kiểm tra 2: Policy "ops" tồn tại ----------------------------------------
if vault policy read ops >/dev/null 2>&1; then
  pass "Policy 'ops' tồn tại"
else
  fail "Policy 'ops' chưa được tạo"
fi

# --- Kiểm tra 3: userpass auth được enable ------------------------------------
if vault auth list -format=json 2>/dev/null | jq -e '."userpass/"' >/dev/null 2>&1; then
  pass "Auth method userpass được enable"
else
  fail "Auth method userpass chưa được enable"
fi

# --- Kiểm tra 4: User "alice" tồn tại trên userpass --------------------------
if vault read auth/userpass/users/alice >/dev/null 2>&1; then
  pass "User 'alice' tồn tại trên userpass"
else
  fail "User 'alice' chưa được tạo trên userpass"
fi

# --- Kiểm tra 5: User "bob" tồn tại trên userpass ----------------------------
if vault read auth/userpass/users/bob >/dev/null 2>&1; then
  pass "User 'bob' tồn tại trên userpass"
else
  fail "User 'bob' chưa được tạo trên userpass"
fi

# --- Kiểm tra 6: Entity "alice-entity" tồn tại --------------------------------
if vault read identity/entity/name/alice-entity >/dev/null 2>&1; then
  pass "Entity 'alice-entity' tồn tại"
else
  fail "Entity 'alice-entity' chưa được tạo"
fi

# --- Kiểm tra 7: Entity "bob-entity" tồn tại ----------------------------------
if vault read identity/entity/name/bob-entity >/dev/null 2>&1; then
  pass "Entity 'bob-entity' tồn tại"
else
  fail "Entity 'bob-entity' chưa được tạo"
fi

# --- Kiểm tra 8: Internal Group "dev-team" tồn tại ---------------------------
if vault read identity/group/name/dev-team >/dev/null 2>&1; then
  pass "Internal Group 'dev-team' tồn tại"
else
  fail "Internal Group 'dev-team' chưa được tạo"
fi

# --- Kiểm tra 9: Group "dev-team" có policy "dev" ----------------------------
DEV_TEAM_POLICIES=$(vault read -format=json identity/group/name/dev-team 2>/dev/null \
  | jq -r '.data.policies // [] | join(",")' 2>/dev/null || echo "")

if echo "$DEV_TEAM_POLICIES" | grep -q "dev"; then
  pass "Group 'dev-team' có policy 'dev'"
else
  fail "Group 'dev-team' chưa được gán policy 'dev' (hiện có: ${DEV_TEAM_POLICIES:-không có})"
fi

# --- Kiểm tra 10: Group "dev-team" là Internal Group -------------------------
DEV_TEAM_TYPE=$(vault read -format=json identity/group/name/dev-team 2>/dev/null \
  | jq -r '.data.type' 2>/dev/null || echo "")

if [ "$DEV_TEAM_TYPE" = "internal" ]; then
  pass "Group 'dev-team' là Internal Group (type=internal)"
else
  fail "Group 'dev-team' không phải Internal Group (type hiện tại: ${DEV_TEAM_TYPE:-không xác định})"
fi

# --- Kiểm tra 11: Group "dev-team" có ít nhất 2 member entities --------------
DEV_TEAM_MEMBER_COUNT=$(vault read -format=json identity/group/name/dev-team 2>/dev/null \
  | jq '.data.member_entity_ids | length' 2>/dev/null || echo "0")

if [ "${DEV_TEAM_MEMBER_COUNT:-0}" -ge 2 ]; then
  pass "Group 'dev-team' có $DEV_TEAM_MEMBER_COUNT member entities (tối thiểu cần 2)"
else
  fail "Group 'dev-team' chỉ có ${DEV_TEAM_MEMBER_COUNT:-0} member entity — cần ít nhất 2 (alice-entity và bob-entity)"
fi

# --- Kiểm tra 12: External Group "ops-team" tồn tại -------------------------
if vault read identity/group/name/ops-team >/dev/null 2>&1; then
  pass "External Group 'ops-team' tồn tại"
else
  fail "External Group 'ops-team' chưa được tạo"
fi

# --- Kiểm tra 13: Group "ops-team" là External Group -------------------------
OPS_TEAM_TYPE=$(vault read -format=json identity/group/name/ops-team 2>/dev/null \
  | jq -r '.data.type' 2>/dev/null || echo "")

if [ "$OPS_TEAM_TYPE" = "external" ]; then
  pass "Group 'ops-team' là External Group (type=external)"
else
  fail "Group 'ops-team' không phải External Group (type hiện tại: ${OPS_TEAM_TYPE:-không xác định})"
fi

# --- Kiểm tra 14: Group "ops-team" có policy "ops" ---------------------------
OPS_TEAM_POLICIES=$(vault read -format=json identity/group/name/ops-team 2>/dev/null \
  | jq -r '.data.policies // [] | join(",")' 2>/dev/null || echo "")

if echo "$OPS_TEAM_POLICIES" | grep -q "ops"; then
  pass "Group 'ops-team' có policy 'ops'"
else
  fail "Group 'ops-team' chưa được gán policy 'ops' (hiện có: ${OPS_TEAM_POLICIES:-không có})"
fi

# --- Kiểm tra 15: Group Alias cho "ops-team" tồn tại -------------------------
OPS_TEAM_ID=$(vault read -format=json identity/group/name/ops-team 2>/dev/null \
  | jq -r '.data.id' 2>/dev/null || echo "")

if [ -n "$OPS_TEAM_ID" ]; then
  # Kiểm tra ops-team có alias không (external group phải có alias)
  ALIAS_COUNT=$(vault read -format=json identity/group/id/"$OPS_TEAM_ID" 2>/dev/null \
    | jq '.data.alias | if . then 1 else 0 end' 2>/dev/null || echo "0")

  if [ "${ALIAS_COUNT:-0}" -eq 1 ]; then
    pass "Group Alias cho 'ops-team' đã được tạo"
  else
    fail "Group Alias cho 'ops-team' chưa được tạo"
  fi
else
  fail "Không thể lấy ID của 'ops-team' để kiểm tra group alias"
fi

# --- Kiểm tra 16: Alice có thể đăng nhập và kế thừa policy từ dev-team ------
ALICE_TOKEN=$(vault write -format=json auth/userpass/login/alice \
  password="training" 2>/dev/null \
  | jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -n "$ALICE_TOKEN" ]; then
  pass "Alice có thể đăng nhập qua userpass"

  # Kiểm tra alice có capabilities đọc secret/data/dev
  ALICE_CAPS=$(VAULT_TOKEN="$ALICE_TOKEN" vault token capabilities secret/data/dev 2>/dev/null || echo "")
  if echo "$ALICE_CAPS" | grep -q "read"; then
    pass "Token của alice có quyền đọc 'secret/data/dev' (từ policy 'dev' qua group 'dev-team')"
  else
    fail "Token của alice không có quyền đọc 'secret/data/dev' — kiểm tra group 'dev-team' và policy 'dev'"
  fi
else
  fail "Không thể đăng nhập bằng user 'alice' — kiểm tra user và password"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
