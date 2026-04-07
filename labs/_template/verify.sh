#!/usr/bin/env bash
# verify.sh — assertion-based "check my answer" script.
#
# Pattern:
#   pass "human-readable description"
#   fail "human-readable description"
#
# Each lab replaces the body below with concrete assertions about Vault state.
# Exit code is 0 only if every check passes.
set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — TEMPLATE"
echo

# Hãy thay các kiểm tra dưới đây bằng nội dung phù hợp với bài của bạn.
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR — bạn đã chạy 'make setup' chưa?"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
