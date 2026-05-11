#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Vòng đời Secrets Engine
#
# Script tự thực hiện toàn bộ các bước của bài lab trong môi trường tạm thời,
# kiểm tra kết quả, rồi dọn dẹp. Học viên có thể chạy lại nhiều lần.
#
# Chạy bằng: bash verify.sh

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

# --- Dọn dẹp trạng thái cũ nếu có -----------------------------------------
vault secrets disable demo-secrets/ >/dev/null 2>&1 || true

# --- Bước 1: Bật KV v2 engine tại path tùy chỉnh demo-secrets/ -------------
vault secrets enable -path=demo-secrets -version=2 kv >/dev/null 2>&1

if vault secrets list -format=json 2>/dev/null | grep -q '"demo-secrets/"'; then
  pass "Bước 1: Engine 'demo-secrets/' đã bật thành công (KV v2)"
else
  fail "Bước 1: Không bật được engine 'demo-secrets/'"
fi

# --- Bước 2+3: Ghi và đọc secret demo-secrets/config ----------------------
vault kv put demo-secrets/config api_key="abc123" >/dev/null 2>&1

if vault kv get -mount=demo-secrets config >/dev/null 2>&1; then
  pass "Bước 2+3: Secret 'demo-secrets/config' có thể đọc được"
else
  fail "Bước 2+3: Không đọc được 'demo-secrets/config'"
fi

api_key_value=$(vault kv get -mount=demo-secrets -field=api_key config 2>/dev/null || echo "")
if [ "$api_key_value" = "abc123" ]; then
  pass "Bước 2+3: Secret chứa api_key=abc123 đúng như yêu cầu"
else
  fail "Bước 2+3: api_key không đúng (nhận được: '${api_key_value}')"
fi

# --- Bước 4: Tune default-lease-ttl thành 2h --------------------------------
vault secrets tune -default-lease-ttl=2h demo-secrets/ >/dev/null 2>&1

default_ttl=$(vault read -field=default_lease_ttl sys/mounts/demo-secrets/tune 2>/dev/null || echo "0")
if [ "$default_ttl" = "7200" ]; then
  pass "Bước 4: default-lease-ttl của 'demo-secrets/' là 7200s (2h)"
else
  fail "Bước 4: default-lease-ttl không đúng (nhận được: ${default_ttl}s, cần: 7200s)"
fi

# --- Bước 5: Disable engine và xác nhận dữ liệu bị xóa -------------------
vault secrets disable demo-secrets/ >/dev/null 2>&1

if vault secrets list -format=json 2>/dev/null | grep -q '"demo-secrets/"'; then
  fail "Bước 5: Engine 'demo-secrets/' vẫn còn sau khi disable"
else
  pass "Bước 5: Engine 'demo-secrets/' đã bị xóa sau khi disable"
fi

if vault kv get -mount=demo-secrets config >/dev/null 2>&1; then
  fail "Bước 5: Dữ liệu 'demo-secrets/config' vẫn còn sau khi disable (không nên)"
else
  pass "Bước 5: Dữ liệu đã bị xóa vĩnh viễn cùng engine"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
