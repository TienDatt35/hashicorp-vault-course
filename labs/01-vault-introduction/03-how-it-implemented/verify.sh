#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Khám phá giới hạn của Vault Community Edition"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Script idempotent: chạy nhiều lần không gây lỗi nếu bài đã hoàn thành.
# Exit code chỉ là 0 khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Khám phá giới hạn của Vault Community Edition"
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

# --- Kiểm tra 1: Đang dùng Community Edition (không có +ent) ----------------
# Vault Community Edition không có chuỗi '+ent' trong output của vault version.
# Nếu có '+ent', đây là Enterprise — bài thực hành không đúng môi trường.
if vault version 2>/dev/null | grep -qv '+ent'; then
  pass "Đang dùng Vault Community Edition (không có '+ent' trong vault version)"
else
  fail "Có vẻ đang dùng Vault Enterprise — bài thực hành thiết kế cho Community Edition"
fi

# --- Kiểm tra 2: Tạo namespace thất bại đúng như kỳ vọng -------------------
# OSS không có endpoint /v1/sys/namespaces — lệnh phải trả về exit code khác 0.
# Đây là hành vi mong đợi, không phải lỗi cấu hình.
if vault namespace create test >/dev/null 2>&1; then
  fail "vault namespace create test thành công — đây không phải Community Edition hoặc có Enterprise license"
else
  pass "vault namespace create test thất bại đúng như kỳ vọng (OSS không có Namespaces)"
fi

# --- Kiểm tra 3: userpass auth method đã được bật ---------------------------
# Dùng vault auth list với format JSON và jq để kiểm tra chính xác.
if vault auth list -format=json 2>/dev/null | jq -e '.["userpass/"].type == "userpass"' >/dev/null 2>&1; then
  pass "userpass auth method đã được bật tại path userpass/"
else
  fail "userpass auth method chưa được bật — hãy chạy: vault auth enable userpass"
fi

# --- Kiểm tra 4: KV v2 engine tại demo/ đã được bật ------------------------
# Kiểm tra options.version == "2" để xác nhận đây là KV v2 (không phải KV v1).
if vault secrets list -format=json 2>/dev/null | jq -e '.["demo/"].options.version == "2"' >/dev/null 2>&1; then
  pass "KV v2 secrets engine đã được bật tại path demo/"
else
  fail "KV v2 secrets engine chưa được bật tại demo/ — hãy chạy: vault secrets enable -path=demo -version=2 kv"
fi

# --- Kiểm tra 5: Secret demo/test có thể ghi và đọc ------------------------
# Ghi secret (idempotent — ghi đè nếu đã tồn tại), sau đó đọc và kiểm tra giá trị.
if vault kv put demo/test key=value >/dev/null 2>&1; then
  # Kiểm tra đọc lại được giá trị đúng
  if vault kv get -format=json demo/test 2>/dev/null | jq -e '.data.data.key == "value"' >/dev/null 2>&1; then
    pass "Secret demo/test có thể ghi và đọc — giá trị key=value xác nhận đúng"
  else
    fail "Ghi demo/test thành công nhưng đọc lại không thấy key=value"
  fi
else
  fail "Không thể ghi secret vào demo/test — kiểm tra KV engine đã bật chưa"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
