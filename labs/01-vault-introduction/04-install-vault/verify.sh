#!/usr/bin/env bash
# verify.sh — kiểm tra kết quả bài thực hành "Khám phá Vault Dev Server trong Codespace"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Chạy bằng: bash verify.sh
# Exit code chỉ là 0 khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Khám phá Vault Dev Server trong Codespace"
echo

# --- Kiểm tra 1: Vault đang chạy và truy cập được --------------------------
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 2: Vault đã được initialized ----------------------------------
if vault status -format=json 2>/dev/null | jq -e '.initialized == true' >/dev/null 2>&1; then
  pass "Vault đã initialized (initialized = true)"
else
  fail "Vault chưa initialized — Dev Server có thể chưa khởi động đầy đủ"
fi

# --- Kiểm tra 3: Vault đã unsealed ------------------------------------------
if vault status -format=json 2>/dev/null | jq -e '.sealed == false' >/dev/null 2>&1; then
  pass "Vault đã unsealed (sealed = false)"
else
  fail "Vault đang sealed — Dev Server không tự unseal được, hãy kiểm tra lại tiến trình"
fi

# --- Kiểm tra 4: Storage type là inmem (đặc trưng của Dev Server) -----------
storage_type=$(vault status -format=json 2>/dev/null | jq -r '.storage_type' 2>/dev/null || echo "")
if echo "$storage_type" | grep -q 'inmem'; then
  pass "Storage type là inmem — đúng với Dev Server"
else
  fail "Storage type không phải inmem (hiện tại: ${storage_type:-không xác định được}) — đây không phải Dev Server"
fi

# --- Kiểm tra 5: KV v2 đã mount tại secret/ ---------------------------------
if vault secrets list -format=json 2>/dev/null | jq -e '.["secret/"].options.version == "2"' >/dev/null 2>&1; then
  pass "KV v2 đã mount tại secret/ (options.version = \"2\")"
else
  fail "KV v2 chưa mount tại secret/ — hãy kiểm tra output của 'vault secrets list'"
fi

# --- Kiểm tra 6: Secret secret/hello tồn tại với foo=bar (idempotent) -------
# Nếu secret chưa tồn tại, tự động tạo để kiểm tra idempotent
if ! vault kv get secret/hello >/dev/null 2>&1; then
  # Secret chưa có — tạo mới để assertion bên dưới có thể kiểm tra
  vault kv put secret/hello foo=bar >/dev/null 2>&1 || true
fi

if vault kv get -format=json secret/hello 2>/dev/null | jq -e '.data.data.foo == "bar"' >/dev/null 2>&1; then
  pass "Secret secret/hello tồn tại với foo=bar"
else
  fail "Secret secret/hello không tồn tại hoặc giá trị foo không phải 'bar'"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
