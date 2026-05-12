#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành KV Secrets Engine (03-static-secret-engine)
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

echo "Đang kiểm tra bài thực hành — KV Secrets Engine (Static Secrets)"
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

# --- Bước 1: Xác nhận KV v2 đang mount tại secret/ -------------------------
if vault secrets list -format=json 2>/dev/null | grep -q '"secret/"'; then
  pass "KV secrets engine đang mount tại secret/"
else
  fail "Không tìm thấy mount secret/ — KV engine chưa được bật"
fi

# Kiểm tra phiên bản là KV v2 (options.version = "2")
kv_version=$(vault secrets list -format=json 2>/dev/null | \
  jq -r '."secret/".options.version // ""' 2>/dev/null || echo "")
if [ "$kv_version" = "2" ]; then
  pass "Mount secret/ là KV v2"
else
  fail "Mount secret/ không phải KV v2 (version='$kv_version')"
fi

# --- Bước 2: Secret training/creds đã được tạo -----------------------------
if vault kv get -mount=secret training/creds >/dev/null 2>&1; then
  pass "Secret training/creds tồn tại trong mount secret/"
else
  fail "Secret training/creds chưa được tạo — hãy chạy bước 2"
fi

# Kiểm tra field username
username_val=$(vault kv get -mount=secret -format=json training/creds 2>/dev/null | \
  jq -r '.data.data.username // ""' 2>/dev/null || echo "")
if [ -n "$username_val" ]; then
  pass "Field 'username' có giá trị trong training/creds"
else
  fail "Field 'username' không có giá trị trong training/creds"
fi

# Kiểm tra field password
password_val=$(vault kv get -mount=secret -format=json training/creds 2>/dev/null | \
  jq -r '.data.data.password // ""' 2>/dev/null || echo "")
if [ -n "$password_val" ]; then
  pass "Field 'password' có giá trị trong training/creds"
else
  fail "Field 'password' không có giá trị trong training/creds"
fi

# --- Bước 3: Secret đã có ít nhất 2 version (sau patch) --------------------
current_version=$(vault kv metadata get -mount=secret -format=json training/creds 2>/dev/null | \
  jq -r '.data.current_version // "0"' 2>/dev/null || echo "0")
if [ "$current_version" -ge 2 ] 2>/dev/null; then
  pass "Secret training/creds có ít nhất 2 version (current_version=$current_version)"
else
  fail "Secret training/creds chưa được cập nhật — cần ít nhất 2 version (hiện tại: $current_version)"
fi

# --- Bước 4 + 6: Version 1 bị destroy (không còn dữ liệu) -----------------
# Sau bước 6, version 1 phải ở trạng thái destroyed
v1_destroyed=$(vault kv metadata get -mount=secret -format=json training/creds 2>/dev/null | \
  jq -r '.data.versions["1"].destroyed // "false"' 2>/dev/null || echo "false")
if [ "$v1_destroyed" = "True" ] || [ "$v1_destroyed" = "true" ]; then
  pass "Version 1 của training/creds đã bị destroy vĩnh viễn"
else
  fail "Version 1 của training/creds chưa bị destroy — hãy chạy bước 6"
fi

# --- Bước 5: Undelete đã được thực hiện (kiểm tra gián tiếp qua destroy) ---
# Bước 5 undelete rồi bước 6 destroy — nếu destroy thành công thì undelete đã xảy ra
# Kiểm tra thêm: version 2 vẫn accessible (không bị xóa nhầm)
if vault kv get -mount=secret -version=2 training/creds >/dev/null 2>&1; then
  pass "Version 2 của training/creds vẫn accessible (không bị xóa nhầm)"
else
  fail "Version 2 của training/creds không accessible — kiểm tra lại bước 5 và 6"
fi

# --- Bước 7: Rollback đã được thực hiện — version count >= 3 ---------------
if [ "$current_version" -ge 3 ] 2>/dev/null; then
  pass "Rollback đã được thực hiện — current_version=$current_version (>= 3)"
else
  fail "Rollback chưa được thực hiện — current_version=$current_version (cần >= 3 sau rollback)"
fi

# Kiểm tra version mới nhất có field username (dữ liệu hợp lệ sau rollback)
latest_username=$(vault kv get -mount=secret -format=json training/creds 2>/dev/null | \
  jq -r '.data.data.username // ""' 2>/dev/null || echo "")
if [ -n "$latest_username" ]; then
  pass "Version mới nhất sau rollback có field 'username' hợp lệ"
else
  fail "Version mới nhất sau rollback thiếu field 'username'"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
