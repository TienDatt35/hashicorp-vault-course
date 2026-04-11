#!/usr/bin/env bash
# verify.sh — kiểm tra đáp án cho bài thực hành
# "Trải nghiệm centralized secrets & encryption as a service"
#
# Quy ước:
#   pass "mô tả ngắn"  -> in dòng [PASS]
#   fail "mô tả ngắn"  -> in dòng [FAIL] và tăng số lỗi
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

echo "Đang kiểm tra bài thực hành — Centralized secrets & Encryption as a Service"
echo

# --- Kiểm tra 1: Vault đang chạy -------------------------------------------
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 2: KV v2 đã mount tại path kv/ --------------------------------
# Kiểm tra engine type là "kv" và option version là "2"
if vault secrets list -format=json 2>/dev/null \
    | jq -e '.["kv/"].type == "kv" and .["kv/"].options.version == "2"' >/dev/null 2>&1; then
  pass "KV v2 đã mount tại path kv/"
else
  fail "KV v2 chưa mount tại path kv/ (chạy: vault secrets enable -version=2 kv)"
fi

# --- Kiểm tra 3: secret kv/app/db tồn tại và password là s3cret-v2 ----------
# Đọc version mới nhất và kiểm tra password
CURRENT_PASSWORD=$(vault kv get -format=json kv/app/db 2>/dev/null \
  | jq -r '.data.data.password' 2>/dev/null || echo "")
if [ "$CURRENT_PASSWORD" = "s3cret-v2" ]; then
  pass "secret kv/app/db tồn tại và password (version mới nhất) là s3cret-v2"
else
  fail "secret kv/app/db không tồn tại hoặc password mới nhất không phải s3cret-v2 (hiện tại: '${CURRENT_PASSWORD}')"
fi

# --- Kiểm tra 4: kv/app/db có ít nhất 2 versions ----------------------------
# Kiểm tra current_version >= 2 qua metadata
CURRENT_VERSION=$(vault kv metadata get -format=json kv/app/db 2>/dev/null \
  | jq -r '.data.current_version' 2>/dev/null || echo "0")
if [ "$CURRENT_VERSION" -ge 2 ] 2>/dev/null; then
  pass "kv/app/db có ít nhất 2 versions (current_version=$CURRENT_VERSION)"
else
  fail "kv/app/db cần ít nhất 2 versions — hãy ghi đè lần 2 với password mới (current_version='${CURRENT_VERSION}')"
fi

# --- Kiểm tra 5: Transit secrets engine đã mount ----------------------------
if vault secrets list -format=json 2>/dev/null \
    | jq -e '.["transit/"].type == "transit"' >/dev/null 2>&1; then
  pass "Transit secrets engine đã mount tại path transit/"
else
  fail "Transit secrets engine chưa mount (chạy: vault secrets enable transit)"
fi

# --- Kiểm tra 6: key my-key tồn tại trong transit ---------------------------
if vault read transit/keys/my-key >/dev/null 2>&1; then
  pass "Key my-key tồn tại trong transit engine"
else
  fail "Key my-key chưa được tạo (chạy: vault write -f transit/keys/my-key)"
fi

# --- Kiểm tra 7: encrypt/decrypt round-trip với my-key ----------------------
# verify.sh tự mã hóa rồi giải mã — không phụ thuộc vào ciphertext của học viên
TEST_STRING="vault-check-123"
TEST_B64=$(echo -n "$TEST_STRING" | base64)

# Mã hóa chuỗi kiểm tra
CIPHERTEXT=$(vault write -format=json transit/encrypt/my-key plaintext="$TEST_B64" 2>/dev/null \
  | jq -r '.data.ciphertext' 2>/dev/null || echo "")

if [ -z "$CIPHERTEXT" ] || [ "$CIPHERTEXT" = "null" ]; then
  fail "Không thể mã hóa bằng my-key — kiểm tra transit engine và key đã tạo đúng chưa"
else
  # Giải mã lại và so sánh
  DECRYPTED_B64=$(vault write -format=json transit/decrypt/my-key ciphertext="$CIPHERTEXT" 2>/dev/null \
    | jq -r '.data.plaintext' 2>/dev/null || echo "")
  DECRYPTED=$(echo "$DECRYPTED_B64" | base64 --decode 2>/dev/null || echo "")

  if [ "$DECRYPTED" = "$TEST_STRING" ]; then
    pass "Transit encrypt/decrypt round-trip thành công (plaintext khớp)"
  else
    fail "Transit decrypt không trả về đúng plaintext (mong đợi: '$TEST_STRING', nhận được: '$DECRYPTED')"
  fi
fi

# --- Kiểm tra 8: Audit device kiểu file đã enable ---------------------------
# Kiểm tra có ít nhất một audit device type=file trong danh sách
if vault audit list -format=json 2>/dev/null \
    | jq -e 'to_entries[] | select(.value.type == "file")' >/dev/null 2>&1; then
  pass "Audit device kiểu file đã được enable"
else
  fail "Chưa có audit device kiểu file (chạy: vault audit enable file file_path=/tmp/vault_audit.log)"
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
