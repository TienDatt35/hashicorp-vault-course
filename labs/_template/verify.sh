#!/usr/bin/env bash
# verify.sh — kịch bản "kiểm tra đáp án" cho bài thực hành.
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Mỗi bài thực hành thay thân kịch bản bên dưới bằng các kiểm tra cụ thể về
# trạng thái Vault sau khi học viên hoàn thành các bước. Exit code chỉ là 0
# khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — TEMPLATE"
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

# --- Hãy thêm các kiểm tra cụ thể của bài học vào đây ----------------------
# Ví dụ:
#   if vault kv get -mount=secret hello >/dev/null 2>&1; then
#     pass "secret/hello tồn tại"
#   else
#     fail "secret/hello chưa được tạo"
#   fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
