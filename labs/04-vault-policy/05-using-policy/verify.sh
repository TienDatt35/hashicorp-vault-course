#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Gán Policy và Kiểm Tra Quyền Truy Cập"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Mỗi bước trong README.md có ít nhất một assertion tương ứng ở đây.
# Exit code chỉ là 0 khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Gán Policy và Kiểm Tra Quyền Truy Cập"
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

# --- Kiểm tra 1: Secret dữ liệu thử nghiệm đã được tạo (Bước 1) -----------
# Xác nhận secret webapp/config tồn tại trên KV v2
if vault kv get -mount=secret webapp/config >/dev/null 2>&1; then
  pass "secret/data/webapp/config tồn tại"
else
  fail "secret/data/webapp/config chưa được tạo — hãy thực hiện Bước 1"
fi

# Xác nhận secret other-app/config tồn tại
if vault kv get -mount=secret other-app/config >/dev/null 2>&1; then
  pass "secret/data/other-app/config tồn tại"
else
  fail "secret/data/other-app/config chưa được tạo — hãy thực hiện Bước 1"
fi

# --- Kiểm tra 2: webapp policy tồn tại và có nội dung đúng (Bước 2) --------
# Kiểm tra policy webapp đã được ghi vào Vault
if vault policy read webapp >/dev/null 2>&1; then
  pass "webapp policy tồn tại trong Vault"
else
  fail "webapp policy chưa được tạo — hãy thực hiện Bước 2"
fi

# Kiểm tra webapp policy có chứa path secret/data/webapp/
if vault policy read webapp 2>/dev/null | grep -q 'secret/data/webapp'; then
  pass "webapp policy có rule cho secret/data/webapp/*"
else
  fail "webapp policy thiếu rule cho secret/data/webapp/* — kiểm tra lại file HCL"
fi

# Kiểm tra webapp policy có chứa path secret/metadata/webapp/ cho list
if vault policy read webapp 2>/dev/null | grep -q 'secret/metadata/webapp'; then
  pass "webapp policy có rule cho secret/metadata/webapp/* (list)"
else
  fail "webapp policy thiếu rule cho secret/metadata/webapp/* — cần thêm rule list"
fi

# --- Kiểm tra 3: Token với webapp policy có đúng policies (Bước 3 + 4) -----
# Tạo token tạm với webapp policy để kiểm tra
WEBAPP_TOKEN=$(vault token create -format=json -policy="webapp" | jq -r ".auth.client_token")

# Kiểm tra token có chứa webapp policy
WEBAPP_POLICIES=$(vault token lookup -format=json "$WEBAPP_TOKEN" | jq -r '.data.policies | @json')
if echo "$WEBAPP_POLICIES" | grep -q '"webapp"'; then
  pass "Token webapp có policy webapp"
else
  fail "Token webapp thiếu policy webapp"
fi

# Kiểm tra token có default policy (hành vi bình thường)
if echo "$WEBAPP_POLICIES" | grep -q '"default"'; then
  pass "Token webapp có default policy (hành vi bình thường)"
else
  fail "Token webapp thiếu default policy — kiểm tra lại cách tạo token"
fi

# --- Kiểm tra 4: Token webapp CÓ capabilities trên allowed path (Bước 4) ---
ALLOWED_CAPS=$(vault token capabilities "$WEBAPP_TOKEN" secret/data/webapp/config 2>/dev/null)
if echo "$ALLOWED_CAPS" | grep -q 'read'; then
  pass "Token webapp có capability read tại secret/data/webapp/config"
else
  fail "Token webapp thiếu capability read tại secret/data/webapp/config — kiểm tra policy HCL"
fi

# --- Kiểm tra 5: Token webapp KHÔNG có capabilities trên denied path (Bước 4) ---
DENIED_CAPS=$(vault token capabilities "$WEBAPP_TOKEN" secret/data/other-app/config 2>/dev/null)
# Kết quả phải là "deny" hoặc danh sách rỗng — không được có "read"
if echo "$DENIED_CAPS" | grep -qE '^(deny|\[\])$'; then
  pass "Token webapp bị từ chối tại secret/data/other-app/config (deny hoặc rỗng)"
elif ! echo "$DENIED_CAPS" | grep -q 'read'; then
  pass "Token webapp không có capability read tại secret/data/other-app/config"
else
  fail "Token webapp có read tại secret/data/other-app/config — policy quá rộng"
fi

# --- Kiểm tra 6: Token webapp bị từ chối khi thực sự đọc denied path (Bước 5) ---
# Thử đọc other-app/config bằng webapp token — phải bị lỗi permission denied
if VAULT_TOKEN="$WEBAPP_TOKEN" vault kv get -mount=secret other-app/config >/dev/null 2>&1; then
  fail "Token webapp đọc được secret/data/other-app/config — policy quá rộng, cần kiểm tra lại"
else
  pass "Token webapp bị từ chối khi đọc secret/data/other-app/config (đúng như mong đợi)"
fi

# Xác nhận token webapp đọc được path được phép
if VAULT_TOKEN="$WEBAPP_TOKEN" vault kv get -mount=secret webapp/config >/dev/null 2>&1; then
  pass "Token webapp đọc được secret/data/webapp/config (đúng như mong đợi)"
else
  fail "Token webapp không đọc được secret/data/webapp/config — kiểm tra lại policy"
fi

# Thu hồi token tạm để dọn dẹp
vault token revoke "$WEBAPP_TOKEN" >/dev/null 2>&1 || true

# --- Kiểm tra 7: operator policy tồn tại và có nội dung đúng (Bước 6) ------
if vault policy read operator >/dev/null 2>&1; then
  pass "operator policy tồn tại trong Vault"
else
  fail "operator policy chưa được tạo — hãy thực hiện Bước 6"
fi

# Kiểm tra operator policy có chứa sys/health
if vault policy read operator 2>/dev/null | grep -q 'sys/health'; then
  pass "operator policy có rule cho sys/health"
else
  fail "operator policy thiếu rule cho sys/health"
fi

# Kiểm tra operator policy có sudo cho sys/auth/*
if vault policy read operator 2>/dev/null | grep -q 'sys/auth'; then
  pass "operator policy có rule cho sys/auth"
else
  fail "operator policy thiếu rule cho sys/auth — cần thêm rules cho sys/auth và sys/auth/*"
fi

# Kiểm tra operator policy có sudo keyword
if vault policy read operator 2>/dev/null | grep -q 'sudo'; then
  pass "operator policy có capability sudo cho root-protected paths"
else
  fail "operator policy thiếu capability sudo — root-protected paths cần sudo"
fi

# --- Kiểm tra 8: Token với operator policy có đúng policies (Bước 7) -------
OPERATOR_TOKEN=$(vault token create -format=json -policy="operator" | jq -r ".auth.client_token")
OPERATOR_POLICIES=$(vault token lookup -format=json "$OPERATOR_TOKEN" | jq -r '.data.policies | @json')

if echo "$OPERATOR_POLICIES" | grep -q '"operator"'; then
  pass "Token operator có policy operator"
else
  fail "Token operator thiếu policy operator"
fi

# Kiểm tra capabilities của operator token tại sys/health
HEALTH_CAPS=$(vault token capabilities "$OPERATOR_TOKEN" sys/health 2>/dev/null)
if echo "$HEALTH_CAPS" | grep -q 'sudo'; then
  pass "Token operator có capability sudo tại sys/health"
else
  fail "Token operator thiếu capability sudo tại sys/health — kiểm tra operator policy"
fi

if echo "$HEALTH_CAPS" | grep -q 'read'; then
  pass "Token operator có capability read tại sys/health"
else
  fail "Token operator thiếu capability read tại sys/health — kiểm tra operator policy"
fi

# Thu hồi operator token tạm
vault token revoke "$OPERATOR_TOKEN" >/dev/null 2>&1 || true

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
