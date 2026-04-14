#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Kiến Trúc Vault và Path-based Routing"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Chạy: bash verify.sh
# Exit code 0 chỉ khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Kiến Trúc Vault và Path-based Routing"
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

# --- Kiểm tra 1: Secrets engine myapp/ đã được enable (Bước 2) ---------------
if vault secrets list 2>/dev/null | grep -q '^myapp/'; then
  pass "Secrets engine myapp/ đã được enable"
else
  fail "Secrets engine myapp/ chưa được enable — chạy: vault secrets enable -path=myapp kv"
fi

# --- Kiểm tra 2: Secret myapp/config tồn tại và có key db_host (Bước 2) ------
kv_output=$(vault kv get -format=json myapp/config 2>/dev/null || true)
if echo "$kv_output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['data']['db_host']=='localhost'" 2>/dev/null; then
  pass "Secret myapp/config tồn tại với db_host=localhost"
else
  fail "Secret myapp/config chưa được tạo hoặc thiếu key db_host=localhost — chạy: vault kv put myapp/config db_host=localhost"
fi

# --- Kiểm tra 3: System Backend sys/ có thể truy cập (Bước 3) ----------------
if vault read sys/mounts >/dev/null 2>&1; then
  pass "System Backend sys/ có thể truy cập và trả về thông tin mount"
else
  fail "Không đọc được sys/mounts — kiểm tra token có quyền không"
fi

# --- Kiểm tra 4: Auth method my-userpass/ đã được enable (Bước 5) ------------
if vault auth list 2>/dev/null | grep -q '^my-userpass/'; then
  pass "Auth method my-userpass/ đã được enable"
else
  fail "Auth method my-userpass/ chưa được enable — chạy: vault auth enable -path=my-userpass userpass"
fi

# --- Kiểm tra 5: User alice tồn tại trong auth/my-userpass/users/ (Bước 5) ---
if vault read auth/my-userpass/users/alice >/dev/null 2>&1; then
  pass "User alice tồn tại trong auth/my-userpass/users/"
else
  fail "User alice chưa được tạo — chạy: vault write auth/my-userpass/users/alice password=password123 policies=default"
fi

# --- Kiểm tra 6: Đăng nhập với alice qua my-userpass thành công (Bước 5) -----
login_output=$(vault login \
  -method=userpass \
  -path=my-userpass \
  -format=json \
  username=alice \
  password=password123 2>/dev/null || true)

if echo "$login_output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['auth']['client_token']" 2>/dev/null; then
  pass "Đăng nhập với alice qua my-userpass thành công và nhận được token"
else
  fail "Không thể đăng nhập với alice qua auth/my-userpass — kiểm tra user và password"
fi

# ---------------------------------------------------------------------------
echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
