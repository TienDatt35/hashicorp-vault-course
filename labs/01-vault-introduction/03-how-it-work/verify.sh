#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: authenticate, token lookup và revoke
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Script tự login bằng alice để lấy token, không phụ thuộc vào biến ngoài.
# Idempotent: chạy nhiều lần không gây lỗi.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — authenticate, token lookup và revoke"
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

# --- Kiểm tra 1: auth method userpass đã được enable -----------------------
# Dùng jq để lấy type từ JSON output, tránh lỗi format
if vault auth list -format=json 2>/dev/null | jq -e '.["userpass/"].type == "userpass"' >/dev/null 2>&1; then
  pass "Auth method 'userpass' đã được enable"
else
  fail "Auth method 'userpass' chưa được enable — hãy chạy: vault auth enable userpass"
fi

# --- Kiểm tra 2: user alice tồn tại ----------------------------------------
if vault read auth/userpass/users/alice >/dev/null 2>&1; then
  pass "User 'alice' tồn tại trong userpass"
else
  fail "User 'alice' chưa được tạo — hãy chạy: vault write auth/userpass/users/alice password=alice-password policies=default"
fi

# --- Kiểm tra 3 & 4: login bằng alice thành công và token hợp lệ -----------
# Script tự login để lấy token, không phụ thuộc vào biến môi trường bên ngoài
ALICE_TOKEN=""
LOGIN_OUTPUT=$(vault login \
  -method=userpass \
  -format=json \
  username=alice \
  password=alice-password \
  2>/dev/null) || true

if [ -n "$LOGIN_OUTPUT" ]; then
  ALICE_TOKEN=$(echo "$LOGIN_OUTPUT" | jq -r '.auth.client_token // empty' 2>/dev/null)
fi

if [ -n "$ALICE_TOKEN" ]; then
  pass "Login bằng alice thành công, nhận được token"
else
  fail "Login bằng alice thất bại — kiểm tra lại password và user"
fi

# Xác nhận token hợp lệ bằng token lookup
if [ -n "$ALICE_TOKEN" ] && vault token lookup "$ALICE_TOKEN" >/dev/null 2>&1; then
  pass "Token của alice hợp lệ (vault token lookup thành công)"
else
  fail "Token của alice không hợp lệ hoặc không lookup được"
fi

# --- Kiểm tra 5: token của alice có policy default -------------------------
if [ -n "$ALICE_TOKEN" ]; then
  POLICIES=$(vault token lookup -format=json "$ALICE_TOKEN" 2>/dev/null \
    | jq -r '.data.policies // [] | join(",")' 2>/dev/null)
  if echo "$POLICIES" | grep -q "default"; then
    pass "Token của alice có policy 'default'"
  else
    fail "Token của alice không có policy 'default' (policies hiện tại: $POLICIES)"
  fi
else
  fail "Không thể kiểm tra policies vì không có token alice hợp lệ"
fi

# --- Kiểm tra 6: secret secret/myapp/config tồn tại với env=production -----
# Dùng root token để đọc secret
SECRET_VAL=$(vault kv get -format=json secret/myapp/config 2>/dev/null \
  | jq -r '.data.data.env // empty' 2>/dev/null)

if [ "$SECRET_VAL" = "production" ]; then
  pass "Secret 'secret/myapp/config' tồn tại với env=production"
else
  fail "Secret 'secret/myapp/config' chưa được tạo hoặc env không phải 'production' (giá trị hiện tại: '${SECRET_VAL:-<trống>}')"
fi

# --- Kiểm tra 7: token alice có capability read tại secret/data/myapp/config
if [ -n "$ALICE_TOKEN" ]; then
  CAPS=$(vault token capabilities "$ALICE_TOKEN" secret/data/myapp/config 2>/dev/null)
  if echo "$CAPS" | grep -q "read"; then
    pass "Token của alice có capability 'read' tại secret/data/myapp/config"
  else
    fail "Token của alice không có capability 'read' tại path đó (capabilities: $CAPS)"
  fi
else
  fail "Không thể kiểm tra capabilities vì không có token alice hợp lệ"
fi

# --- Kiểm tra 8: revoke token alice rồi xác nhận bị từ chối ---------------
# Revoke token alice đã login ở trên
if [ -n "$ALICE_TOKEN" ]; then
  vault token revoke "$ALICE_TOKEN" >/dev/null 2>&1 || true

  # Sau khi revoke, dùng token đó phải bị từ chối
  if VAULT_TOKEN="$ALICE_TOKEN" vault token lookup >/dev/null 2>&1; then
    fail "Token alice vẫn hoạt động sau khi revoke — kiểm tra lại bước revoke"
  else
    pass "Sau khi revoke, token alice bị từ chối đúng như kỳ vọng"
  fi
else
  fail "Không thể kiểm tra revoke vì không có token alice hợp lệ"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
