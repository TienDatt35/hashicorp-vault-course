#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành Transit Auto Unseal
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Script này kiểm tra:
#   1. Vault A (port 8200) có thể truy cập
#   2. Transit engine đã được enable trên Vault A
#   3. Key autounseal-vault-b đã tồn tại trên Vault A
#   4. Policy autounseal-vault-b đã tồn tại trên Vault A
#   5. File config Vault B tồn tại và có chứa seal "transit"
#   6. Vault B (port 8300) có thể truy cập
#   7. Vault B đã unsealed
#   8. Vault B đang dùng Transit seal (Recovery Seal Type xuất hiện)

set -uo pipefail

# --- Cấu hình biến môi trường cho Vault A -----------------------------------
: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

# Địa chỉ Vault B — cluster phụ chạy tại port 8300
VAULT_B_ADDR="http://127.0.0.1:8300"

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Transit Auto Unseal"
echo

# --- Kiểm tra 1: Vault A đang chạy tại port 8200 ----------------------------
if vault status >/dev/null 2>&1; then
  pass "Vault A có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault A tại $VAULT_ADDR"
  echo
  echo "Vault dev server (Vault A) chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 2: Transit Secrets Engine đã được enable trên Vault A ---------
if vault secrets list -format=json 2>/dev/null | grep -q '"transit/"'; then
  pass "Transit Secrets Engine đã được enable trên Vault A"
else
  fail "Transit Secrets Engine chưa được enable — chạy: vault secrets enable transit"
fi

# --- Kiểm tra 3: Key autounseal-vault-b đã tồn tại --------------------------
if vault read -format=json transit/keys/autounseal-vault-b >/dev/null 2>&1; then
  pass "Key 'autounseal-vault-b' đã tồn tại trên Transit engine"
else
  fail "Key 'autounseal-vault-b' chưa được tạo — chạy: vault write -f transit/keys/autounseal-vault-b"
fi

# --- Kiểm tra 4: Policy autounseal-vault-b đã tồn tại -----------------------
if vault policy read autounseal-vault-b >/dev/null 2>&1; then
  pass "Policy 'autounseal-vault-b' đã tồn tại trên Vault A"
else
  fail "Policy 'autounseal-vault-b' chưa được tạo — xem README bước 4"
fi

# --- Kiểm tra 5: File config Vault B tồn tại và có seal "transit" -----------
VAULT_B_CONFIG="/tmp/vault-b/config.hcl"
if [ -f "$VAULT_B_CONFIG" ]; then
  if grep -q 'seal "transit"' "$VAULT_B_CONFIG"; then
    pass "File config Vault B tồn tại tại $VAULT_B_CONFIG và có seal \"transit\" stanza"
  else
    fail "File config tồn tại tại $VAULT_B_CONFIG nhưng thiếu seal \"transit\" stanza"
  fi
else
  fail "File config Vault B không tìm thấy tại $VAULT_B_CONFIG — xem README bước 6"
fi

# --- Kiểm tra 6: Vault B có thể truy cập tại port 8300 ----------------------
if VAULT_ADDR="$VAULT_B_ADDR" vault status >/dev/null 2>&1; then
  pass "Vault B có thể truy cập tại $VAULT_B_ADDR"
else
  fail "Không truy cập được Vault B tại $VAULT_B_ADDR — xem README bước 7"
fi

# --- Kiểm tra 7: Vault B đã unsealed -----------------------------------------
VAULT_B_SEALED=$(VAULT_ADDR="$VAULT_B_ADDR" vault status -format=json 2>/dev/null | grep -o '"sealed":[^,}]*' | head -1 | grep -o 'true\|false' || echo "unknown")
if [ "$VAULT_B_SEALED" = "false" ]; then
  pass "Vault B đã unsealed (Sealed: false)"
else
  fail "Vault B vẫn đang sealed hoặc chưa được init — xem README bước 9"
fi

# --- Kiểm tra 8: Vault B dùng Transit seal (có Recovery Seal Type) ----------
if VAULT_ADDR="$VAULT_B_ADDR" vault status 2>/dev/null | grep -q "Recovery Seal Type"; then
  pass "Vault B đang dùng Transit Auto Unseal (Recovery Seal Type xuất hiện trong vault status)"
else
  fail "Không thấy 'Recovery Seal Type' trong vault status của Vault B — Vault B có thể chưa được cấu hình đúng seal \"transit\""
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
