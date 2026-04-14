#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Vault Initialization
#
# Script này kiểm tra Vault production server tại port 8300
# (không phải dev server tại port 8200).
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi

set -uo pipefail

# Trỏ vào Vault production server (port 8300), không phải dev server
: "${VAULT_ADDR:=http://127.0.0.1:8300}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Vault Initialization (port 8300)"
echo

# --- Kiểm tra 0: Vault production server có thể truy cập tại port 8300 --------
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault production server chưa chạy. Hãy khởi động với lệnh:"
  echo "  nohup vault server -config=/tmp/vault-init-lab/config.hcl >/tmp/vault-init-lab/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 1: Config file tồn tại ------------------------------------------
if [ -f /tmp/vault-init-lab/config.hcl ]; then
  pass "Config file tồn tại tại /tmp/vault-init-lab/config.hcl"
else
  fail "Config file chưa tồn tại tại /tmp/vault-init-lab/config.hcl"
fi

# --- Kiểm tra 2: Vault đã được initialized ------------------------------------
initialized=$(vault status -format=json 2>/dev/null | grep -o '"initialized":[^,}]*' | grep -o 'true\|false' || echo "unknown")
if [ "$initialized" = "true" ]; then
  pass "Vault production đã được initialized (Initialized = true)"
else
  fail "Vault production chưa được initialized — hãy chạy: vault operator init -key-shares=3 -key-threshold=2"
fi

# --- Kiểm tra 3: Vault đã được unsealed ----------------------------------------
sealed=$(vault status -format=json 2>/dev/null | grep -o '"sealed":[^,}]*' | grep -o 'true\|false' || echo "unknown")
if [ "$sealed" = "false" ]; then
  pass "Vault production đã được unsealed (Sealed = false)"
else
  fail "Vault production vẫn đang sealed — hãy chạy vault operator unseal với đủ 2 keys"
fi

# --- Kiểm tra 4: Key threshold đúng -------------------------------------------
threshold=$(vault status -format=json 2>/dev/null | grep -o '"t":[0-9]*' | grep -o '[0-9]*' || echo "0")
if [ "$threshold" = "2" ]; then
  pass "Key threshold đúng (Threshold = 2)"
else
  fail "Key threshold không đúng — mong đợi 2, thực tế: ${threshold}. Hãy dùng -key-threshold=2 khi init"
fi

# --- Kiểm tra 5: Total shares đúng --------------------------------------------
shares=$(vault status -format=json 2>/dev/null | grep -o '"n":[0-9]*' | grep -o '[0-9]*' || echo "0")
if [ "$shares" = "3" ]; then
  pass "Tổng số key shares đúng (Total Shares = 3)"
else
  fail "Tổng số key shares không đúng — mong đợi 3, thực tế: ${shares}. Hãy dùng -key-shares=3 khi init"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
