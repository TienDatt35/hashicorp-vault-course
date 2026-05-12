#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành Cubbyhole và Response Wrapping
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Chạy bằng: sh verify.sh

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Cubbyhole và Response Wrapping"
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

# --- Bước 1: cubbyhole/lab-note đã được ghi bằng root token ----------------
if vault read cubbyhole/lab-note >/dev/null 2>&1; then
  pass "cubbyhole/lab-note tồn tại trong cubbyhole của root token"
else
  fail "cubbyhole/lab-note chưa được tạo — hãy chạy bước 1"
fi

# Kiểm tra field content có giá trị
content_val=$(vault read -format=json cubbyhole/lab-note 2>/dev/null | \
  jq -r '.data.content // ""' 2>/dev/null || echo "")
if [ -n "$content_val" ]; then
  pass "Field 'content' có giá trị trong cubbyhole/lab-note"
else
  fail "Field 'content' không có giá trị trong cubbyhole/lab-note"
fi

# --- Bước 2: Xác nhận isolation — tạo token mới và kiểm tra ----------------
# Kiểm tra gián tiếp: tạo token mới và đảm bảo cubbyhole của nó trống
NEW_TOKEN=$(vault token create -policy=default -format=json 2>/dev/null | \
  jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -n "$NEW_TOKEN" ]; then
  pass "Tạo token mới với policy default thành công"

  # Cubbyhole của token mới phải trống (không có lab-note của root)
  isolation_output=$(VAULT_TOKEN="$NEW_TOKEN" vault read cubbyhole/lab-note 2>&1 || true)
  if echo "$isolation_output" | grep -q "No value found\|not found\|404"; then
    pass "Token mới không đọc được cubbyhole/lab-note của root — isolation hoạt động đúng"
  elif [ -z "$isolation_output" ] || ! echo "$isolation_output" | grep -q "content"; then
    pass "Token mới không đọc được dữ liệu cubbyhole của root — isolation hoạt động đúng"
  else
    fail "Token mới đọc được cubbyhole của root — isolation bị lỗi (không nên xảy ra)"
  fi

  # Revoke token mới sau khi kiểm tra để giữ môi trường sạch
  vault token revoke "$NEW_TOKEN" >/dev/null 2>&1 || true
else
  fail "Không tạo được token mới — kiểm tra lại môi trường Vault"
fi

# --- Bước 3: Secret KV lab/db-password đã được tạo -------------------------
if vault kv get -mount=secret lab/db-password >/dev/null 2>&1; then
  pass "Secret lab/db-password tồn tại trong mount secret/"
else
  fail "Secret lab/db-password chưa được tạo — hãy chạy bước 3"
fi

# Kiểm tra field value có giá trị
db_val=$(vault kv get -mount=secret -format=json lab/db-password 2>/dev/null | \
  jq -r '.data.data.value // ""' 2>/dev/null || echo "")
if [ -n "$db_val" ]; then
  pass "Field 'value' có giá trị trong lab/db-password"
else
  fail "Field 'value' không có giá trị trong lab/db-password"
fi

# --- Bước 3 + 4: Thực hiện Response Wrapping và kiểm tra creation_path -----
# Tạo wrapping token mới để kiểm tra cơ chế hoạt động
WRAP_TOKEN=$(vault read -wrap-ttl=30s -format=json secret/data/lab/db-password 2>/dev/null | \
  jq -r '.wrap_info.token // ""' 2>/dev/null || echo "")

if [ -n "$WRAP_TOKEN" ]; then
  pass "vault read -wrap-ttl thành công — nhận được wrapping token"

  # Kiểm tra creation_path qua API /sys/wrapping/lookup
  creation_path=$(curl -s \
    -X POST \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"token\": \"$WRAP_TOKEN\"}" \
    "$VAULT_ADDR/v1/sys/wrapping/lookup" 2>/dev/null | \
    jq -r '.data.creation_path // ""' 2>/dev/null || echo "")

  if [ "$creation_path" = "secret/data/lab/db-password" ]; then
    pass "creation_path khớp với path mong đợi: $creation_path"
  else
    fail "creation_path không đúng (nhận được: '$creation_path', mong đợi: 'secret/data/lab/db-password')"
  fi

  # --- Bước 5: Unwrap để lấy secret thật ------------------------------------
  unwrap_val=$(vault unwrap -format=json "$WRAP_TOKEN" 2>/dev/null | \
    jq -r '.data.data.value // ""' 2>/dev/null || echo "")

  if [ -n "$unwrap_val" ]; then
    pass "vault unwrap thành công — lấy được giá trị secret thật"
  else
    fail "vault unwrap thất bại hoặc không trả về giá trị — kiểm tra lại bước 5"
  fi

  # --- Bước 6: Thử unwrap lần hai — phải thất bại (single-use) --------------
  second_unwrap_output=$(vault unwrap "$WRAP_TOKEN" 2>&1 || true)
  if echo "$second_unwrap_output" | grep -qi "not valid\|does not exist\|400\|error"; then
    pass "Unwrap lần hai thất bại đúng như mong đợi — wrapping token là single-use"
  else
    fail "Unwrap lần hai không báo lỗi — single-use behavior có vấn đề"
  fi
else
  fail "vault read -wrap-ttl thất bại — không nhận được wrapping token"
  fail "Không thể kiểm tra creation_path (wrapping token không có)"
  fail "Không thể kiểm tra unwrap (wrapping token không có)"
  fail "Không thể kiểm tra single-use behavior (wrapping token không có)"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
