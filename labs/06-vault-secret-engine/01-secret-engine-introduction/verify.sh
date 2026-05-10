#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Vòng đời Secrets Engine
#
# Chạy script này SAU khi hoàn thành Bước 1-4 (trước Bước 5 disable).
# Script kiểm tra:
#   1. Vault có thể truy cập
#   2. Engine "demo-secrets/" tồn tại trong danh sách
#   3. Secret "demo-secrets/config" đọc được và chứa api_key=abc123
#   4. default-lease-ttl của engine là 7200 giây (2h)

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Vòng đời Secrets Engine"
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

# --- Kiểm tra 1: Engine demo-secrets/ tồn tại trong danh sách --------------
if vault secrets list -format=json 2>/dev/null | grep -q '"demo-secrets/"'; then
  pass "Engine 'demo-secrets/' tồn tại trong danh sách secrets engine"
else
  fail "Không tìm thấy 'demo-secrets/' — hãy chạy: vault secrets enable -path=demo-secrets -version=2 kv"
fi

# --- Kiểm tra 2: Secret demo-secrets/config đọc được -----------------------
if vault kv get -mount=demo-secrets config >/dev/null 2>&1; then
  pass "Secret 'demo-secrets/config' có thể đọc được"
else
  fail "Không đọc được 'demo-secrets/config' — hãy chạy: vault kv put demo-secrets/config api_key=\"abc123\""
fi

# --- Kiểm tra 3: api_key có giá trị abc123 ---------------------------------
api_key_value=$(vault kv get -mount=demo-secrets -field=api_key config 2>/dev/null || echo "")
if [ "$api_key_value" = "abc123" ]; then
  pass "Secret 'demo-secrets/config' chứa api_key=abc123 đúng như yêu cầu"
else
  fail "api_key không đúng (nhận được: '${api_key_value}') — hãy chạy: vault kv put demo-secrets/config api_key=\"abc123\""
fi

# --- Kiểm tra 4: default-lease-ttl sau tune là 7200 giây (2h) -------------
# Đọc từ sys/mounts để lấy thông số tune hiện tại
default_ttl=$(vault read -field=default_lease_ttl sys/mounts/demo-secrets/tune 2>/dev/null || echo "0")
if [ "$default_ttl" = "7200" ]; then
  pass "default-lease-ttl của engine 'demo-secrets/' là 7200 giây (2h) đúng như yêu cầu"
else
  fail "default-lease-ttl không đúng (nhận được: ${default_ttl}s, cần: 7200s) — hãy chạy: vault secrets tune -default-lease-ttl=2h demo-secrets/"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
