#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Giới thiệu Auth Methods"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Chạy bộ kiểm tra này SAU KHI hoàn thành bước 1-5 (trước bước 8 disable).
# Exit code 0 chỉ khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Giới thiệu Auth Methods"
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

# --- Kiểm tra 1: token auth method có sẵn (bước 1) -------------------------
if vault auth list -format=json 2>/dev/null | grep -q '"token/"'; then
  pass "token/ auth method có sẵn trong danh sách (mặc định, không thể disable)"
else
  fail "token/ auth method không tìm thấy trong vault auth list"
fi

# --- Kiểm tra 2: userpass auth method đã được enable (bước 2) ---------------
if vault auth list -format=json 2>/dev/null | grep -q '"userpass/"'; then
  pass "userpass/ auth method đã được enable"
else
  fail "userpass/ auth method chưa được enable — hãy chạy: vault auth enable userpass"
fi

# --- Kiểm tra 3: user alice đã tồn tại (bước 3) ----------------------------
if vault read -format=json auth/userpass/users/alice >/dev/null 2>&1; then
  pass "User alice đã được tạo trong userpass auth method"
else
  fail "User alice chưa tồn tại — hãy chạy: vault write auth/userpass/users/alice password=vault123 policies=default"
fi

# --- Kiểm tra 4: login bằng alice trả về token hợp lệ (bước 4) -------------
LOGIN_TOKEN=$(vault login -method=userpass -token-only username=alice password=vault123 2>/dev/null)
if [ -n "$LOGIN_TOKEN" ]; then
  pass "Login bằng alice thành công — nhận được token"
else
  fail "Login bằng alice thất bại — kiểm tra lại password và policy"
fi

# --- Kiểm tra 5: token của alice có policy default (bước 5) ----------------
if [ -n "${LOGIN_TOKEN:-}" ]; then
  ALICE_POLICIES=$(VAULT_TOKEN="$LOGIN_TOKEN" vault token lookup -format=json 2>/dev/null | grep -o '"default"')
  if [ "$ALICE_POLICIES" = '"default"' ]; then
    pass "Token của alice có policy 'default'"
  else
    fail "Token của alice không có policy 'default' — kiểm tra lại lệnh write user"
  fi
else
  fail "Không thể kiểm tra policy vì login thất bại ở bước trước"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
