#!/usr/bin/env bash
# verify.sh — kiểm tra kết quả bài thực hành "Các Thành Phần Cốt Lõi của Vault"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Chạy bằng: bash verify.sh
# Exit code 0 chỉ khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Các Thành Phần Cốt Lõi của Vault"
echo

# --- Kiểm tra 0: Vault đang chạy và có thể truy cập ---------------------
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 1: Secrets engine "secret/" đã được enable (Bước 2) -------
if vault secrets list -format=json 2>/dev/null | grep -q '"secret/"'; then
  pass "Secrets engine được mount tại path 'secret/' đã được enable"
else
  fail "Secrets engine tại 'secret/' chưa được enable — chạy: vault secrets enable -path=secret kv"
fi

# --- Kiểm tra 2: Secrets engine "kv-dev/" đã được enable (Bước 2) ------
if vault secrets list -format=json 2>/dev/null | grep -q '"kv-dev/"'; then
  pass "Secrets engine được mount tại path 'kv-dev/' đã được enable"
else
  fail "Secrets engine tại 'kv-dev/' chưa được enable — chạy: vault secrets enable -path=kv-dev kv"
fi

# --- Kiểm tra 3: Secret "secret/my-app" tồn tại và có key "password" (Bước 2) ---
if vault kv get -format=json secret/my-app 2>/dev/null | grep -q '"password"'; then
  pass "Secret 'secret/my-app' tồn tại và có key 'password'"
else
  fail "Secret 'secret/my-app' chưa được tạo hoặc thiếu key 'password' — chạy: vault kv put secret/my-app password=<giá_trị>"
fi

# --- Kiểm tra 4: Auth method "userpass/" đã được enable (Bước 3) --------
if vault auth list -format=json 2>/dev/null | grep -q '"userpass/"'; then
  pass "Auth method 'userpass/' đã được enable"
else
  fail "Auth method 'userpass/' chưa được enable — chạy: vault auth enable userpass"
fi

# --- Kiểm tra 5: User "alice" tồn tại trong userpass (Bước 3) -----------
if vault read -format=json auth/userpass/users/alice >/dev/null 2>&1; then
  pass "User 'alice' tồn tại trong auth method userpass"
else
  fail "User 'alice' chưa được tạo — chạy: vault write auth/userpass/users/alice password=<mật_khẩu> policies=default"
fi

# --- Kiểm tra 6: Audit device "file/" đã được enable (Bước 4) -----------
if vault audit list -format=json 2>/dev/null | grep -q '"file/"'; then
  pass "Audit device loại 'file/' đã được enable"
else
  fail "Audit device 'file/' chưa được enable — chạy: vault audit enable file file_path=/tmp/vault-audit.log"
fi

# --- Kiểm tra 7: File audit log tồn tại và không rỗng (Bước 5) ----------
audit_log="/tmp/vault-audit.log"
if [ -f "$audit_log" ] && [ -s "$audit_log" ]; then
  pass "File audit log '$audit_log' tồn tại và có nội dung"
else
  fail "File audit log '$audit_log' chưa tồn tại hoặc đang rỗng — thực hiện bất kỳ thao tác Vault nào để kích hoạt ghi log"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
