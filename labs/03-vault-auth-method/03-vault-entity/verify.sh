#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Hợp nhất identity với Vault Entities và Aliases"
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

echo "Đang kiểm tra bài thực hành — Vault Entities và Aliases"
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

# --- Kiểm tra 1: Policy "test" tồn tại -------------------------------------
if vault policy read test >/dev/null 2>&1; then
  pass "Policy 'test' tồn tại"
else
  fail "Policy 'test' chưa được tạo"
fi

# --- Kiểm tra 2: Policy "team-qa" tồn tại ----------------------------------
if vault policy read team-qa >/dev/null 2>&1; then
  pass "Policy 'team-qa' tồn tại"
else
  fail "Policy 'team-qa' chưa được tạo"
fi

# --- Kiểm tra 3: Policy "base" tồn tại -------------------------------------
if vault policy read base >/dev/null 2>&1; then
  pass "Policy 'base' tồn tại"
else
  fail "Policy 'base' chưa được tạo"
fi

# --- Kiểm tra 4: userpass-test được enable ----------------------------------
if vault auth list -format=json 2>/dev/null | jq -e '."userpass-test/"' >/dev/null 2>&1; then
  pass "Auth method userpass-test được enable"
else
  fail "Auth method userpass-test chưa được enable"
fi

# --- Kiểm tra 5: userpass-qa được enable ------------------------------------
if vault auth list -format=json 2>/dev/null | jq -e '."userpass-qa/"' >/dev/null 2>&1; then
  pass "Auth method userpass-qa được enable"
else
  fail "Auth method userpass-qa chưa được enable"
fi

# --- Kiểm tra 6: User "bob" tồn tại trên userpass-test ---------------------
if vault read auth/userpass-test/users/bob >/dev/null 2>&1; then
  pass "User 'bob' tồn tại trên userpass-test"
else
  fail "User 'bob' chưa được tạo trên userpass-test"
fi

# --- Kiểm tra 7: User "bsmith" tồn tại trên userpass-qa -------------------
if vault read auth/userpass-qa/users/bsmith >/dev/null 2>&1; then
  pass "User 'bsmith' tồn tại trên userpass-qa"
else
  fail "User 'bsmith' chưa được tạo trên userpass-qa"
fi

# --- Kiểm tra 8: Entity "bob-smith" tồn tại ---------------------------------
if vault read identity/entity/name/bob-smith >/dev/null 2>&1; then
  pass "Entity 'bob-smith' tồn tại"
else
  fail "Entity 'bob-smith' chưa được tạo"
fi

# --- Kiểm tra 9: Entity "bob-smith" có policy "base" ------------------------
ENTITY_POLICIES=$(vault read -format=json identity/entity/name/bob-smith 2>/dev/null \
  | jq -r '.data.policies // [] | join(",")' 2>/dev/null || echo "")

if echo "$ENTITY_POLICIES" | grep -q "base"; then
  pass "Entity 'bob-smith' có policy 'base'"
else
  fail "Entity 'bob-smith' chưa được gán policy 'base' (hiện có: ${ENTITY_POLICIES:-không có})"
fi

# --- Kiểm tra 10: Entity "bob-smith" có ít nhất 2 aliases -------------------
ALIAS_COUNT=$(vault read -format=json identity/entity/name/bob-smith 2>/dev/null \
  | jq '.data.aliases | length' 2>/dev/null || echo "0")

if [ "${ALIAS_COUNT:-0}" -ge 2 ]; then
  pass "Entity 'bob-smith' có $ALIAS_COUNT aliases (tối thiểu cần 2)"
else
  fail "Entity 'bob-smith' chỉ có ${ALIAS_COUNT:-0} alias(es) — cần ít nhất 2"
fi

# --- Kiểm tra 11: Alias "bob" tồn tại và trỏ đến entity bob-smith ----------
ACCESSOR_TEST=$(vault auth list -format=json 2>/dev/null \
  | jq -r '.["userpass-test/"].accessor' 2>/dev/null || echo "")

if [ -n "$ACCESSOR_TEST" ]; then
  # Kiểm tra alias bob tồn tại trên mount userpass-test
  ALIAS_BOB=$(vault read -format=json identity/entity/name/bob-smith 2>/dev/null \
    | jq -r --arg acc "$ACCESSOR_TEST" '.data.aliases[] | select(.mount_accessor == $acc) | .name' 2>/dev/null || echo "")

  if [ "$ALIAS_BOB" = "bob" ]; then
    pass "Alias 'bob' được gắn vào entity 'bob-smith' qua mount userpass-test"
  else
    fail "Alias 'bob' chưa được gắn đúng vào entity 'bob-smith' qua userpass-test"
  fi
else
  fail "Không thể lấy accessor của userpass-test để kiểm tra alias 'bob'"
fi

# --- Kiểm tra 12: Alias "bsmith" tồn tại và trỏ đến entity bob-smith -------
ACCESSOR_QA=$(vault auth list -format=json 2>/dev/null \
  | jq -r '.["userpass-qa/"].accessor' 2>/dev/null || echo "")

if [ -n "$ACCESSOR_QA" ]; then
  ALIAS_BSMITH=$(vault read -format=json identity/entity/name/bob-smith 2>/dev/null \
    | jq -r --arg acc "$ACCESSOR_QA" '.data.aliases[] | select(.mount_accessor == $acc) | .name' 2>/dev/null || echo "")

  if [ "$ALIAS_BSMITH" = "bsmith" ]; then
    pass "Alias 'bsmith' được gắn vào entity 'bob-smith' qua mount userpass-qa"
  else
    fail "Alias 'bsmith' chưa được gắn đúng vào entity 'bob-smith' qua userpass-qa"
  fi
else
  fail "Không thể lấy accessor của userpass-qa để kiểm tra alias 'bsmith'"
fi

# --- Kiểm tra 13: Token của bob kế thừa policy "base" từ entity -------------
# Đăng nhập bằng bob và kiểm tra token có entity_id của bob-smith
ENTITY_ID=$(vault read -format=json identity/entity/name/bob-smith 2>/dev/null \
  | jq -r '.data.id' 2>/dev/null || echo "")

if [ -n "$ENTITY_ID" ]; then
  # Lấy token của bob
  BOB_TOKEN=$(vault write -format=json auth/userpass-test/login/bob \
    password="training" 2>/dev/null \
    | jq -r '.auth.client_token' 2>/dev/null || echo "")

  if [ -n "$BOB_TOKEN" ]; then
    # Kiểm tra entity_id trong token của bob
    TOKEN_ENTITY=$(VAULT_TOKEN="$BOB_TOKEN" vault token lookup -format=json 2>/dev/null \
      | jq -r '.data.entity_id' 2>/dev/null || echo "")

    if [ "$TOKEN_ENTITY" = "$ENTITY_ID" ]; then
      pass "Token của 'bob' liên kết với entity 'bob-smith' (entity_id khớp)"
    else
      fail "Token của 'bob' không liên kết với entity 'bob-smith' (entity_id không khớp)"
    fi
  else
    fail "Không thể đăng nhập bằng user 'bob' để kiểm tra entity liên kết"
  fi
else
  fail "Không thể lấy entity_id của 'bob-smith' để kiểm tra"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
