#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Unseal Vault bằng Key Shards"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Học viên chạy: bash verify.sh

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
export VAULT_ADDR

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Unseal Vault bằng Key Shards"
echo

# --- Kiểm tra 0: Vault có thể truy cập ----------------------------------------
# vault status trả về exit code khác 0 khi sealed, dùng || true để không thoát script
STATUS_OUTPUT=$(vault status 2>&1) || true

if echo "$STATUS_OUTPUT" | grep -q "Seal Type"; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "  Vault server chưa chạy. Hãy khởi động Vault production mode:"
  echo "    vault server -config=/tmp/vault-lab/config.hcl > /tmp/vault-lab/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 1: Vault đang chạy ở production mode (có Shamir, không phải dev) ---
# Dev mode dùng "shamir" nhưng Initialized luôn true và không có unseal process
# Kiểm tra config file tồn tại để phân biệt production mode
if [ -f "/tmp/vault-lab/config.hcl" ]; then
  pass "Config file production mode tồn tại tại /tmp/vault-lab/config.hcl"
else
  fail "Không tìm thấy /tmp/vault-lab/config.hcl — bạn chưa tạo config cho production mode"
fi

# --- Kiểm tra 2: Vault đã được initialized ------------------------------------
INITIALIZED=$(echo "$STATUS_OUTPUT" | grep "^Initialized" | awk '{print $2}')
if [ "$INITIALIZED" = "true" ]; then
  pass "Vault đã được initialized (Initialized = true)"
else
  fail "Vault chưa được initialized — hãy chạy: vault operator init -key-shares=3 -key-threshold=2"
fi

# --- Kiểm tra 3: Vault đã được unsealed ----------------------------------------
SEALED=$(echo "$STATUS_OUTPUT" | grep "^Sealed" | awk '{print $2}')
if [ "$SEALED" = "false" ]; then
  pass "Vault đã được unsealed (Sealed = false)"
else
  fail "Vault vẫn đang sealed — hãy nộp đủ unseal key shares bằng: vault operator unseal"
fi

# --- Kiểm tra 4: Key threshold đúng (threshold = 2) ----------------------------
THRESHOLD=$(echo "$STATUS_OUTPUT" | grep "^Threshold" | awk '{print $2}')
if [ "$THRESHOLD" = "2" ]; then
  pass "Key threshold đúng (Threshold = 2)"
else
  fail "Key threshold không đúng — mong đợi 2, nhận được: ${THRESHOLD:-không tìm thấy}. Hãy init lại với -key-threshold=2"
fi

# --- Kiểm tra 5: Total shares đúng (total shares = 3) -------------------------
TOTAL_SHARES=$(echo "$STATUS_OUTPUT" | grep "^Total Shares" | awk '{print $3}')
if [ "$TOTAL_SHARES" = "3" ]; then
  pass "Total shares đúng (Total Shares = 3)"
else
  fail "Total shares không đúng — mong đợi 3, nhận được: ${TOTAL_SHARES:-không tìm thấy}. Hãy init lại với -key-shares=3"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
