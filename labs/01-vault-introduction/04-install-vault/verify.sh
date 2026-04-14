#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Cài Vault từ binary, cấu hình, khởi tạo và unseal"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Script kiểm tra instance Vault riêng ở port 8300 (không phải dev server 8200).
# Chạy bằng: bash verify.sh

set -uo pipefail

LAB_DIR="$HOME/vault-lab"
LAB_VAULT="$LAB_DIR/vault"
LAB_CONFIG="$LAB_DIR/config.hcl"
LAB_INIT="$LAB_DIR/init.txt"
LAB_ADDR="http://127.0.0.1:8300"

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Cài Vault từ binary, cấu hình, khởi tạo và unseal"
echo

# --- Kiểm tra 1: binary vault tồn tại và đúng version ----------------------
if [ -f "$LAB_VAULT" ] && [ -x "$LAB_VAULT" ]; then
  pass "Binary vault tồn tại tại $LAB_VAULT"
else
  fail "Không tìm thấy binary tại $LAB_VAULT — hãy tải và giải nén vault_1.21.4_linux_386.zip"
fi

if "$LAB_VAULT" version 2>/dev/null | grep -q "1.21.4"; then
  pass "Vault binary đúng version 1.21.4"
else
  ACTUAL=$("$LAB_VAULT" version 2>/dev/null || echo "không đọc được")
  fail "Version không khớp (hiện tại: $ACTUAL) — cần 1.21.4"
fi

# --- Kiểm tra 2: config file tồn tại và có các trường bắt buộc -------------
if [ -f "$LAB_CONFIG" ]; then
  pass "Config file tồn tại tại $LAB_CONFIG"
else
  fail "Không tìm thấy config file tại $LAB_CONFIG — hãy tạo file config.hcl"
fi

if [ -f "$LAB_CONFIG" ] && grep -q 'storage "file"' "$LAB_CONFIG"; then
  pass "Config có storage \"file\" block"
else
  fail "Config thiếu block storage \"file\""
fi

if [ -f "$LAB_CONFIG" ] && grep -q '8300' "$LAB_CONFIG"; then
  pass "Config listener dùng port 8300"
else
  fail "Config không dùng port 8300 — kiểm tra listener block"
fi

# --- Kiểm tra 3: Vault ở port 8300 có thể truy cập ------------------------
if VAULT_ADDR="$LAB_ADDR" "$LAB_VAULT" status >/dev/null 2>&1 || \
   curl -sf "$LAB_ADDR/v1/sys/health" >/dev/null 2>&1; then
  pass "Vault tại $LAB_ADDR có thể truy cập"
else
  fail "Không truy cập được Vault tại $LAB_ADDR — đảm bảo server đã khởi động"
  echo
  echo "Khởi động lại server:"
  echo "  nohup $LAB_VAULT server -config=$LAB_CONFIG > $LAB_DIR/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 4: Vault đã initialized ---------------------------------------
INIT_STATUS=$(curl -sf "$LAB_ADDR/v1/sys/health" 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('initialized','false'))" 2>/dev/null || echo "false")

if [ "$INIT_STATUS" = "True" ] || \
   VAULT_ADDR="$LAB_ADDR" "$LAB_VAULT" status -format=json 2>/dev/null | \
   grep -q '"initialized": *true'; then
  pass "Vault đã initialized (operator init đã chạy)"
else
  fail "Vault chưa initialized — hãy chạy: VAULT_ADDR=$LAB_ADDR $LAB_VAULT operator init -key-shares=3 -key-threshold=2"
fi

# --- Kiểm tra 5: Vault đã unsealed ------------------------------------------
SEALED_STATUS=$(VAULT_ADDR="$LAB_ADDR" "$LAB_VAULT" status -format=json 2>/dev/null | \
  grep '"sealed"' | grep -o 'true\|false' || echo "true")

if [ "$SEALED_STATUS" = "false" ]; then
  pass "Vault đã unsealed (sealed = false)"
else
  fail "Vault đang sealed — hãy chạy operator unseal đủ 2 lần với 2 key khác nhau"
fi

# --- Kiểm tra 6: file init.txt tồn tại và có root token --------------------
if [ -f "$LAB_INIT" ]; then
  pass "File init.txt tồn tại tại $LAB_INIT"
else
  fail "Không tìm thấy $LAB_INIT — hãy lưu output của operator init vào file này"
fi

ROOT_TOKEN=""
if [ -f "$LAB_INIT" ]; then
  ROOT_TOKEN=$(grep "Initial Root Token" "$LAB_INIT" | awk '{print $NF}' 2>/dev/null || echo "")
fi

if [ -n "$ROOT_TOKEN" ]; then
  pass "Tìm thấy root token trong init.txt"
else
  fail "Không tìm thấy root token trong init.txt — kiểm tra lại nội dung file"
fi

# --- Kiểm tra 7: đăng nhập được và list secrets engines --------------------
if [ -n "$ROOT_TOKEN" ]; then
  ENGINES=$(VAULT_ADDR="$LAB_ADDR" VAULT_TOKEN="$ROOT_TOKEN" \
    "$LAB_VAULT" secrets list -format=json 2>/dev/null || echo "")

  if echo "$ENGINES" | grep -q '"cubbyhole/"'; then
    pass "Đăng nhập bằng root token thành công, secrets engines mặc định có mặt"
  else
    fail "Đăng nhập thất bại hoặc không liệt kê được secrets engines — kiểm tra root token"
  fi
else
  fail "Bỏ qua kiểm tra secrets engines vì không có root token"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
