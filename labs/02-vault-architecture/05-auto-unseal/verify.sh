#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành Auto Unseal với KMS
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Auto Unseal với KMS"
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

# --- Kiểm tra 1: Vault dev server đang dùng Shamir -------------------------
# Bước 1 trong README: học viên quan sát vault status của dev server
SEAL_TYPE=$(vault status -format=json 2>/dev/null | grep -o '"seal_type":"[^"]*"' | cut -d'"' -f4)
if [ "$SEAL_TYPE" = "shamir" ]; then
  pass "Vault dev server đang dùng Seal Type = shamir (đúng như bài lý thuyết mô tả)"
else
  fail "Seal Type không phải 'shamir' (nhận được: '$SEAL_TYPE') — kiểm tra lại VAULT_ADDR"
fi

# --- Kiểm tra 2: File cấu hình AWS KMS tồn tại và hợp lệ ------------------
# Bước 2 trong README: học viên tạo /tmp/vault-awskms.hcl
AWSKMS_CONFIG="/tmp/vault-awskms.hcl"
if [ -f "$AWSKMS_CONFIG" ]; then
  pass "File $AWSKMS_CONFIG tồn tại"
else
  fail "File $AWSKMS_CONFIG chưa được tạo — hãy hoàn thành bước 2"
fi

# Kiểm tra file chứa seal stanza awskms
if [ -f "$AWSKMS_CONFIG" ] && grep -q 'seal.*"awskms"' "$AWSKMS_CONFIG"; then
  pass "$AWSKMS_CONFIG chứa seal stanza cho awskms"
else
  fail "$AWSKMS_CONFIG không chứa seal \"awskms\" { ... } — kiểm tra lại cú pháp"
fi

# Kiểm tra có khai báo kms_key_id
if [ -f "$AWSKMS_CONFIG" ] && grep -q 'kms_key_id' "$AWSKMS_CONFIG"; then
  pass "$AWSKMS_CONFIG khai báo tham số kms_key_id"
else
  fail "$AWSKMS_CONFIG thiếu tham số kms_key_id"
fi

# Kiểm tra có khai báo region
if [ -f "$AWSKMS_CONFIG" ] && grep -q 'region' "$AWSKMS_CONFIG"; then
  pass "$AWSKMS_CONFIG khai báo tham số region"
else
  fail "$AWSKMS_CONFIG thiếu tham số region"
fi

# Kiểm tra có storage stanza
if [ -f "$AWSKMS_CONFIG" ] && grep -q 'storage' "$AWSKMS_CONFIG"; then
  pass "$AWSKMS_CONFIG có storage stanza"
else
  fail "$AWSKMS_CONFIG thiếu storage stanza"
fi

# --- Kiểm tra 3: File phân tích vault status tồn tại ----------------------
# Bước 4 trong README: học viên tạo /tmp/vault-status-analysis.txt
ANALYSIS_FILE="/tmp/vault-status-analysis.txt"
if [ -f "$ANALYSIS_FILE" ]; then
  pass "File $ANALYSIS_FILE tồn tại"
else
  fail "File $ANALYSIS_FILE chưa được tạo — hãy hoàn thành bước 4"
fi

# --- Kiểm tra 4: File cấu hình Azure Key Vault tồn tại và hợp lệ ----------
# Bước 5 trong README: học viên tạo /tmp/vault-azurekeyvault.hcl
AZURE_CONFIG="/tmp/vault-azurekeyvault.hcl"
if [ -f "$AZURE_CONFIG" ]; then
  pass "File $AZURE_CONFIG tồn tại"
else
  fail "File $AZURE_CONFIG chưa được tạo — hãy hoàn thành bước 5"
fi

# Kiểm tra file chứa seal stanza azurekeyvault
if [ -f "$AZURE_CONFIG" ] && grep -q 'seal.*"azurekeyvault"' "$AZURE_CONFIG"; then
  pass "$AZURE_CONFIG chứa seal stanza cho azurekeyvault"
else
  fail "$AZURE_CONFIG không chứa seal \"azurekeyvault\" { ... } — kiểm tra lại cú pháp"
fi

# Kiểm tra có khai báo vault_name
if [ -f "$AZURE_CONFIG" ] && grep -q 'vault_name' "$AZURE_CONFIG"; then
  pass "$AZURE_CONFIG khai báo tham số vault_name"
else
  fail "$AZURE_CONFIG thiếu tham số vault_name"
fi

# Kiểm tra có khai báo key_name
if [ -f "$AZURE_CONFIG" ] && grep -q 'key_name' "$AZURE_CONFIG"; then
  pass "$AZURE_CONFIG khai báo tham số key_name"
else
  fail "$AZURE_CONFIG thiếu tham số key_name"
fi

# Kiểm tra có khai báo tenant_id
if [ -f "$AZURE_CONFIG" ] && grep -q 'tenant_id' "$AZURE_CONFIG"; then
  pass "$AZURE_CONFIG khai báo tham số tenant_id"
else
  fail "$AZURE_CONFIG thiếu tham số tenant_id"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
