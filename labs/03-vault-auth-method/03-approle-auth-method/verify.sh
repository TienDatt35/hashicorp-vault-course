#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành AppRole Auth Method
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Exit code chỉ là 0 khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — AppRole Auth Method"
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

# --- Kiểm tra 1: AppRole auth method đã được bật (Bước 1) -------------------
if vault auth list 2>/dev/null | grep -q '^approle/'; then
  pass "AppRole auth method đã được bật tại đường dẫn approle/"
else
  fail "AppRole auth method chưa được bật — chạy: vault auth enable approle"
fi

# --- Kiểm tra 2: Role my-app tồn tại (Bước 2) --------------------------------
if vault read auth/approle/role/my-app >/dev/null 2>&1; then
  pass "Role my-app tồn tại"
else
  fail "Role my-app chưa được tạo — xem Bước 2 trong README"
fi

# --- Kiểm tra 3: Tham số token_policies của role (Bước 2) --------------------
POLICIES=$(vault read -field=token_policies auth/approle/role/my-app 2>/dev/null || echo "")
if echo "$POLICIES" | grep -q "default"; then
  pass "Role my-app có token_policies chứa 'default'"
else
  fail "Role my-app chưa có token_policies=default"
fi

# --- Kiểm tra 4: Tham số secret_id_num_uses của role (Bước 2) ----------------
NUM_USES=$(vault read -field=secret_id_num_uses auth/approle/role/my-app 2>/dev/null || echo "")
if [ "$NUM_USES" = "5" ]; then
  pass "Role my-app có secret_id_num_uses=5"
else
  fail "secret_id_num_uses chưa đúng (hiện tại: '$NUM_USES', cần: '5')"
fi

# --- Kiểm tra 5: Tham số secret_id_ttl của role (Bước 2) ---------------------
SID_TTL=$(vault read -field=secret_id_ttl auth/approle/role/my-app 2>/dev/null || echo "")
if [ "$SID_TTL" = "30m" ] || [ "$SID_TTL" = "1800" ] || [ "$SID_TTL" = "1800s" ]; then
  pass "Role my-app có secret_id_ttl=30m"
else
  fail "secret_id_ttl chưa đúng (hiện tại: '$SID_TTL', cần: '30m' / '1800s')"
fi

# --- Kiểm tra 6: RoleID có thể đọc được (Bước 3) -----------------------------
ROLE_ID=$(vault read -field=role_id auth/approle/role/my-app/role-id 2>/dev/null || echo "")
if [ -n "$ROLE_ID" ]; then
  pass "RoleID có thể đọc được: ${ROLE_ID:0:8}..."
else
  fail "Không đọc được RoleID của role my-app"
fi

# --- Kiểm tra 7: Có thể sinh SecretID (Bước 4) -------------------------------
SECRET_ID=$(vault write -force -field=secret_id auth/approle/role/my-app/secret-id 2>/dev/null || echo "")
if [ -n "$SECRET_ID" ]; then
  pass "SecretID có thể được sinh thành công (Pull mode)"
else
  fail "Không thể sinh SecretID cho role my-app"
fi

# --- Kiểm tra 8: Login bằng AppRole thành công (Bước 5 + 6) ------------------
if [ -n "$ROLE_ID" ] && [ -n "$SECRET_ID" ]; then
  LOGIN_TOKEN=$(vault write -field=token auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID" 2>/dev/null || echo "")
  if [ -n "$LOGIN_TOKEN" ]; then
    pass "Login bằng AppRole thành công, nhận được token"
  else
    fail "Login bằng AppRole thất bại — kiểm tra ROLE_ID và SECRET_ID"
  fi
else
  fail "Bỏ qua kiểm tra login vì không có ROLE_ID hoặc SECRET_ID"
fi

# --- Kiểm tra 9: Token lấy được có policy default (Bước 7) -------------------
if [ -n "${LOGIN_TOKEN:-}" ]; then
  TOKEN_POLICIES=$(vault token lookup -format=json "$LOGIN_TOKEN" 2>/dev/null | jq -r '.data.policies | join(" ")' 2>/dev/null || echo "")
  if echo "$TOKEN_POLICIES" | grep -q "default"; then
    pass "Token từ AppRole login mang policy 'default'"
  else
    fail "Token từ AppRole login không mang policy 'default' (hiện tại: '$TOKEN_POLICIES')"
  fi
else
  fail "Bỏ qua kiểm tra policy vì login thất bại ở bước trước"
fi

# --- Kiểm tra 10: SecretID hết hiệu lực sau num_uses lần dùng (Bước 8) -------
if [ -n "$ROLE_ID" ]; then
  # Sinh SecretID mới để kiểm tra giới hạn
  TEST_SID=$(vault write -force -field=secret_id auth/approle/role/my-app/secret-id 2>/dev/null || echo "")
  if [ -n "$TEST_SID" ]; then
    # Dùng đủ 5 lần (lần 1-5)
    for _i in 1 2 3 4 5; do
      vault write auth/approle/login \
        role_id="$ROLE_ID" \
        secret_id="$TEST_SID" >/dev/null 2>&1 || true
    done
    # Lần thứ 6 phải thất bại
    SIXTH_RESULT=$(vault write auth/approle/login \
      role_id="$ROLE_ID" \
      secret_id="$TEST_SID" 2>&1 || true)
    if echo "$SIXTH_RESULT" | grep -qi "invalid\|expired\|error\|failed\|num_uses"; then
      pass "SecretID bị vô hiệu sau khi dùng đủ 5 lần (secret_id_num_uses hoạt động)"
    else
      fail "SecretID vẫn hoạt động sau lần thứ 6 — secret_id_num_uses có thể chưa đúng"
    fi
  else
    fail "Không thể sinh SecretID để kiểm tra giới hạn num_uses"
  fi
else
  fail "Bỏ qua kiểm tra num_uses vì không có ROLE_ID"
fi

# --- Kiểm tra 11: Sinh SecretID mới và login lại thành công (Bước 9) ---------
if [ -n "$ROLE_ID" ]; then
  NEW_SID=$(vault write -force -field=secret_id auth/approle/role/my-app/secret-id 2>/dev/null || echo "")
  if [ -n "$NEW_SID" ]; then
    NEW_TOKEN=$(vault write -field=token auth/approle/login \
      role_id="$ROLE_ID" \
      secret_id="$NEW_SID" 2>/dev/null || echo "")
    if [ -n "$NEW_TOKEN" ]; then
      pass "Login lại thành công với SecretID mới sau khi SecretID cũ hết hiệu lực"
    else
      fail "Login với SecretID mới thất bại — kiểm tra lại role"
    fi
  else
    fail "Không thể sinh SecretID mới để kiểm tra phục hồi"
  fi
else
  fail "Bỏ qua kiểm tra phục hồi vì không có ROLE_ID"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
