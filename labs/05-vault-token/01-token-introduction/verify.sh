#!/usr/bin/env bash
# verify.sh — kiểm tra kết quả bài thực hành "Giới thiệu Vault Token"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Chạy: sh verify.sh

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Giới thiệu Vault Token"
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

# --- Bước 1: Token hiện tại có thể lookup được ------------------------------
echo
echo "Bước 1 — Kiểm tra token hiện tại"

if vault token lookup >/dev/null 2>&1; then
  pass "vault token lookup thực thi thành công"
else
  fail "vault token lookup thất bại — kiểm tra VAULT_TOKEN"
fi

# Xác nhận root token là loại service token
TOKEN_TYPE=$(vault token lookup -format=json 2>/dev/null | grep '"type"' | head -1 | sed 's/.*"type": "\([^"]*\)".*/\1/')
if [ "$TOKEN_TYPE" = "service" ]; then
  pass "Root token có type = service (đúng như kỳ vọng)"
else
  fail "Root token không có type = service (nhận được: $TOKEN_TYPE)"
fi

# --- Bước 2: Tạo service token thành công -----------------------------------
echo
echo "Bước 2 — Tạo service token"

SERVICE_TOKEN=$(vault token create -ttl=1h -policy=default -field=token 2>/dev/null)
if [ -n "$SERVICE_TOKEN" ]; then
  pass "Tạo service token thành công"
else
  fail "Không tạo được service token"
fi

# Kiểm tra prefix của service token: hvs. (>= 1.10) hoặc s. (< 1.10)
if echo "$SERVICE_TOKEN" | grep -qE '^hvs\.|^s\.'; then
  pass "Service token có prefix đúng (hvs. hoặc s.)"
else
  fail "Service token không có prefix hvs. hoặc s. (nhận được: ${SERVICE_TOKEN:0:6}...)"
fi

# --- Bước 3: Service token hoạt động được -----------------------------------
echo
echo "Bước 3 — Dùng service token"

if VAULT_TOKEN=$SERVICE_TOKEN vault token lookup >/dev/null 2>&1; then
  pass "Service token vừa tạo có thể dùng để lookup"
else
  fail "Service token vừa tạo không hoạt động"
fi

# Thu hồi service token sau khi kiểm tra
vault token revoke "$SERVICE_TOKEN" >/dev/null 2>&1 || true

# --- Bước 4: Batch token có prefix đúng và không thể renew ------------------
echo
echo "Bước 4 — Tạo batch token và kiểm tra không renew được"

BATCH_TOKEN=$(vault token create -type=batch -ttl=1h -policy=default -field=token 2>/dev/null)
if [ -n "$BATCH_TOKEN" ]; then
  pass "Tạo batch token thành công"
else
  fail "Không tạo được batch token"
fi

# Kiểm tra prefix của batch token: hvb. (>= 1.10) hoặc b. (< 1.10)
if echo "$BATCH_TOKEN" | grep -qE '^hvb\.|^b\.'; then
  pass "Batch token có prefix đúng (hvb. hoặc b.)"
else
  fail "Batch token không có prefix hvb. hoặc b. (nhận được: ${BATCH_TOKEN:0:6}...)"
fi

# Batch token không thể renew — lệnh phải thất bại
if vault token renew "$BATCH_TOKEN" >/dev/null 2>&1; then
  fail "Batch token renew thành công (không đúng — batch token không được phép renew)"
else
  pass "Batch token không thể renew (đúng hành vi kỳ vọng)"
fi

# --- Bước 5: Token use-limit bị revoke sau đủ số lần dùng ------------------
echo
echo "Bước 5 — Token giới hạn số lần dùng"

USE_LIMIT_TOKEN=$(vault token create -use-limit=3 -ttl=1h -policy=default -field=token 2>/dev/null)
if [ -n "$USE_LIMIT_TOKEN" ]; then
  pass "Tạo token use-limit=3 thành công"
else
  fail "Không tạo được token use-limit=3"
  echo
  if [ "$failures" -eq 0 ]; then
    echo "Tất cả kiểm tra đều đạt."
    exit 0
  else
    echo "$failures kiểm tra chưa đạt."
    exit 1
  fi
fi

# Dùng token 3 lần (mỗi lần là một lần dùng theo Vault)
VAULT_TOKEN=$USE_LIMIT_TOKEN vault token lookup >/dev/null 2>&1 || true
VAULT_TOKEN=$USE_LIMIT_TOKEN vault token lookup >/dev/null 2>&1 || true
VAULT_TOKEN=$USE_LIMIT_TOKEN vault token lookup >/dev/null 2>&1 || true

# Lần thứ 4 phải thất bại vì token đã bị revoke
if VAULT_TOKEN=$USE_LIMIT_TOKEN vault token lookup >/dev/null 2>&1; then
  fail "Token vẫn hoạt động sau 3 lần dùng (kỳ vọng bị revoke)"
else
  pass "Token use-limit=3 bị revoke tự động sau đủ 3 lần dùng"
fi

# --- Kết quả cuối -----------------------------------------------------------
echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
