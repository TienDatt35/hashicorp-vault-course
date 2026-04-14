#!/usr/bin/env bash
# verify.sh — kiểm tra kết quả bài thực hành:
# "Bảo Vệ Dữ Liệu trong Vault: Encryption và Unseal"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Bảo Vệ Dữ Liệu trong Vault: Encryption và Unseal"
echo

# --- Kiểm tra 0: Vault đang chạy (bước 1) ------------------------------------
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 1: Vault đang ở trạng thái unsealed (bước 1) -------------------
sealed_status=$(vault status -format=json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['sealed'])" 2>/dev/null || echo "true")
if [ "$sealed_status" = "False" ] || [ "$sealed_status" = "false" ]; then
  pass "Vault đang ở trạng thái unsealed (Sealed = false)"
else
  fail "Vault đang ở trạng thái sealed — dev server có thể chưa khởi động đúng"
fi

# --- Kiểm tra 2: sys/key-status trả về dữ liệu hợp lệ (bước 2) --------------
key_status_output=$(vault read -format=json sys/key-status 2>/dev/null)
if echo "$key_status_output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['data']['term'] >= 1" 2>/dev/null; then
  current_term=$(echo "$key_status_output" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['term'])" 2>/dev/null)
  pass "sys/key-status trả về dữ liệu hợp lệ (term hiện tại: $current_term)"
else
  fail "Không đọc được thông tin key-status từ sys/key-status"
fi

# --- Kiểm tra 3: Encryption key đã được rotate ít nhất một lần (bước 3) -----
# term > 1 chứng tỏ học viên đã chạy vault operator rotate
term_value=$(vault read -format=json sys/key-status 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['term'])" 2>/dev/null || echo "0")
if [ "$term_value" -gt 1 ] 2>/dev/null; then
  pass "Encryption key đã được rotate (term = $term_value > 1)"
else
  fail "Encryption key chưa được rotate — term hiện tại là $term_value, cần > 1. Hãy chạy: vault operator rotate"
fi

# --- Kiểm tra 4: sys/rotate/config trả về thành công (bước 4) ---------------
rotate_config_output=$(vault read -format=json sys/rotate/config 2>/dev/null)
if echo "$rotate_config_output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'interval' in d['data']" 2>/dev/null; then
  pass "sys/rotate/config trả về thành công (trường interval có mặt)"
else
  fail "Không đọc được cấu hình auto-rotate từ sys/rotate/config"
fi

# --- Kiểm tra 5: Secret test-after-rotate tồn tại (bước 3 mở rộng) ----------
if vault kv get secret/test-after-rotate >/dev/null 2>&1; then
  pass "Secret secret/test-after-rotate tồn tại — Vault hoạt động bình thường sau key rotation"
else
  fail "Secret secret/test-after-rotate chưa được tạo — hãy chạy: vault kv put secret/test-after-rotate message='kiem tra sau khi rotate'"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
