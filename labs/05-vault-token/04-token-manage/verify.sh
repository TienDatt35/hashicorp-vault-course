#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Quản lý Vault Token bằng CLI"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Chạy: sh verify.sh
# Exit 0 chỉ khi mọi assertion đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Quản lý Vault Token bằng CLI"
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

# --- Kiểm tra 1: Policy lab-policy tồn tại (Bước 1) ------------------------
if vault policy read lab-policy >/dev/null 2>&1; then
  pass "Policy 'lab-policy' tồn tại trong Vault"
else
  fail "Policy 'lab-policy' chưa được tạo — hãy hoàn thành Bước 1"
fi

# --- Kiểm tra 2: Policy lab-policy có đúng nội dung (Bước 1) ----------------
# Kiểm tra policy có chứa capabilities read và path secret/data/lab/*
POLICY_CONTENT=$(vault policy read lab-policy 2>/dev/null || echo "")
if echo "$POLICY_CONTENT" | grep -q 'secret/data/lab/\*' && \
   echo "$POLICY_CONTENT" | grep -q '"read"'; then
  pass "Policy 'lab-policy' chứa path 'secret/data/lab/*' với capability 'read'"
else
  fail "Policy 'lab-policy' không đúng — cần path 'secret/data/lab/*' với capability 'read'"
fi

# --- Kiểm tra 3: Có thể tạo token với policy lab-policy (Bước 2) -----------
# Tạo token tạm để kiểm tra, sau đó sẽ revoke
TEST_TOKEN=$(vault token create \
  -policy=lab-policy \
  -ttl=5m \
  -explicit-max-ttl=10m \
  -display-name=verify-test-token \
  -format=json 2>/dev/null \
  | jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -n "$TEST_TOKEN" ] && [ "$TEST_TOKEN" != "null" ]; then
  pass "Có thể tạo token với policy 'lab-policy'"
else
  fail "Không thể tạo token với policy 'lab-policy'"
  # Nếu không tạo được token, các bước kiểm tra tiếp theo không thể chạy
  echo
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi

# --- Kiểm tra 4: capabilities trả về read cho secret/data/lab/test (Bước 4) --
CAPS_LAB=$(vault token capabilities "$TEST_TOKEN" secret/data/lab/test 2>/dev/null || echo "")
if echo "$CAPS_LAB" | grep -q "read"; then
  pass "Token với 'lab-policy' có capability 'read' trên 'secret/data/lab/test'"
else
  fail "Token với 'lab-policy' không có capability 'read' trên 'secret/data/lab/test' — capabilities hiện tại: $CAPS_LAB"
fi

# --- Kiểm tra 5: capabilities trả về deny cho secret/data/other (Bước 4) ---
CAPS_OTHER=$(vault token capabilities "$TEST_TOKEN" secret/data/other 2>/dev/null || echo "")
if echo "$CAPS_OTHER" | grep -q "deny"; then
  pass "Token với 'lab-policy' bị từ chối (deny) trên 'secret/data/other'"
else
  fail "Token với 'lab-policy' không bị deny trên 'secret/data/other' — capabilities hiện tại: $CAPS_OTHER"
fi

# --- Kiểm tra 6: vault token renew thành công (Bước 5) ----------------------
RENEW_OUTPUT=$(vault token renew -increment=2m "$TEST_TOKEN" 2>&1 || echo "FAILED")
if echo "$RENEW_OUTPUT" | grep -q "token_duration\|token_renewable\|lease_duration"; then
  pass "vault token renew thành công với -increment"
else
  fail "vault token renew thất bại — output: $RENEW_OUTPUT"
fi

# --- Kiểm tra 7: Sau khi revoke, token không còn valid (Bước 6) -------------
# Thu hồi token test
vault token revoke "$TEST_TOKEN" >/dev/null 2>&1

# Thử lookup token đã bị revoke — phải trả về lỗi
LOOKUP_OUTPUT=$(vault token lookup "$TEST_TOKEN" 2>&1 || true)
if echo "$LOOKUP_OUTPUT" | grep -qiE "bad token|invalid token|403|permission denied|Code: 4"; then
  pass "Token đã bị revoke — lookup trả về lỗi như mong đợi"
else
  fail "Token vẫn còn hiệu lực sau khi revoke — lookup không báo lỗi"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
