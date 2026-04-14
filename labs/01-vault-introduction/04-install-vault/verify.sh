#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Cài Vault từ binary, cấu hình, khởi tạo và unseal"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Kiểm tra instance Vault riêng ở port 8300 (không phải dev server 8200).
# Chạy bằng: bash verify.sh

set -u pipefail

LAB_DIR="$HOME/vault-lab"
LAB_CONFIG="$LAB_DIR/config.hcl"
LAB_INIT="$LAB_DIR/init.txt"
LAB_ADDR="http://127.0.0.1:8300"

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Cài Vault từ binary, cấu hình, khởi tạo và unseal"
echo

# --- Kiểm tra 1: vault binary trong PATH, đúng version ---------------------
if command -v vault >/dev/null 2>&1; then
  pass "Lệnh vault có trong PATH ($(command -v vault))"
else
  fail "Lệnh vault không tìm thấy trong PATH — hãy copy binary vào /usr/local/bin/vault"
fi

if vault version 2>/dev/null | grep -q "1.21.4"; then
  pass "Vault đúng version 1.21.4"
else
  ACTUAL=$(vault version 2>/dev/null || echo "không đọc được")
  fail "Version không khớp (hiện tại: $ACTUAL) — cần 1.21.4"
fi

# --- Kiểm tra 2: config file tồn tại và có các trường bắt buộc ------------
if [ -f "$LAB_CONFIG" ]; then
  pass "Config file tồn tại tại $LAB_CONFIG"
else
  fail "Không tìm thấy $LAB_CONFIG — hãy copy vault-lab.hcl ra ~/vault-lab/config.hcl"
fi

if [ -f "$LAB_CONFIG" ] && grep -q 'storage "file"' "$LAB_CONFIG"; then
  pass "Config có block storage \"file\""
else
  fail "Config thiếu block storage \"file\""
fi

if [ -f "$LAB_CONFIG" ] && grep -q '8300' "$LAB_CONFIG"; then
  pass "Config listener dùng port 8300"
else
  fail "Config không có port 8300 — kiểm tra listener block"
fi

# --- Kiểm tra 3: Vault ở port 8300 có thể truy cập ------------------------
if VAULT_ADDR="$LAB_ADDR" vault status >/dev/null 2>&1; then
  pass "Vault tại $LAB_ADDR có thể truy cập"
else
  fail "Không truy cập được Vault tại $LAB_ADDR — đảm bảo server đã khởi động"
  echo
  echo "Khởi động lại server:"
  echo "  nohup vault server -config=$LAB_CONFIG > $LAB_DIR/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 4: Vault đã initialized --------------------------------------
if VAULT_ADDR="$LAB_ADDR" vault status -format=json 2>/dev/null | \
   grep -q '"initialized": *true'; then
  pass "Vault đã initialized"
else
  fail "Vault chưa initialized — hãy chạy: VAULT_ADDR=$LAB_ADDR vault operator init -key-shares=3 -key-threshold=2"
fi

# --- Kiểm tra 5: Vault đã unsealed -----------------------------------------
SEALED=$(VAULT_ADDR="$LAB_ADDR" vault status -format=json 2>/dev/null | \
  grep '"sealed"' | grep -o 'true\|false' || echo "true")

if [ "$SEALED" = "false" ]; then
  pass "Vault đã unsealed"
else
  fail "Vault đang sealed — hãy chạy operator unseal đủ 2 lần với 2 key khác nhau"
fi

# --- Kiểm tra 6: init.txt tồn tại và có root token ------------------------
if [ -f "$LAB_INIT" ]; then
  pass "File init.txt tồn tại tại $LAB_INIT"
else
  fail "Không tìm thấy $LAB_INIT — lưu output của operator init vào file này"
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

# --- Kiểm tra 7: đăng nhập được và list secrets engines -------------------
if [ -n "$ROOT_TOKEN" ]; then
  ENGINES=$(VAULT_ADDR="$LAB_ADDR" VAULT_TOKEN="$ROOT_TOKEN" \
    vault secrets list -format=json 2>/dev/null || echo "")

  if echo "$ENGINES" | grep -q '"cubbyhole/"'; then
    pass "Đăng nhập bằng root token thành công, secrets engines mặc định có mặt"
  else
    fail "Đăng nhập thất bại hoặc không liệt kê được secrets engines"
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
