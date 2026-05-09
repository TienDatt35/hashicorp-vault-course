#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Xác thực vào Vault bằng Token"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Exit code 0 chỉ khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Xác thực vào Vault bằng Token"
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

# --- Kiểm tra 1: vault token lookup hoạt động (bước 1) ----------------------
if VAULT_TOKEN=root vault token lookup >/dev/null 2>&1; then
  pass "vault token lookup hoạt động với VAULT_TOKEN=root"
else
  fail "vault token lookup thất bại với VAULT_TOKEN=root"
fi

# --- Kiểm tra 2: Token không hợp lệ bị từ chối (bước 2) --------------------
if VAULT_TOKEN=invalid vault token lookup >/dev/null 2>&1; then
  fail "Token không hợp lệ vẫn được chấp nhận (không mong đợi)"
else
  pass "Token không hợp lệ bị từ chối đúng như mong đợi"
fi

# --- Kiểm tra 3: X-Vault-Token header hoạt động (bước 3) -------------------
http_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "X-Vault-Token: root" \
  "${VAULT_ADDR}/v1/auth/token/lookup-self")

if [ "$http_code" = "200" ]; then
  pass "GET /v1/auth/token/lookup-self với X-Vault-Token: root trả HTTP 200"
else
  fail "GET /v1/auth/token/lookup-self với X-Vault-Token trả HTTP $http_code (mong đợi 200)"
fi

# --- Kiểm tra 4: Gọi không có token trả 403 (bước 4) -----------------------
no_token_code=$(curl -s -o /dev/null -w "%{http_code}" \
  "${VAULT_ADDR}/v1/auth/token/lookup-self")

if [ "$no_token_code" = "403" ]; then
  pass "Gọi API không có token trả HTTP 403 đúng như mong đợi"
else
  fail "Gọi API không có token trả HTTP $no_token_code (mong đợi 403)"
fi

# --- Kiểm tra 5: Secret tại team-a/config đã được tạo (bước 5) -------------
if VAULT_TOKEN=root vault kv get secret/team-a/config >/dev/null 2>&1; then
  pass "Secret secret/team-a/config đã tồn tại"
else
  fail "Secret secret/team-a/config chưa được tạo — chạy: vault kv put secret/team-a/config env=production region=us-east-1"
fi

# --- Kiểm tra 6: Policy team-a-readonly đã được tạo (bước 6) ---------------
if VAULT_TOKEN=root vault policy read team-a-readonly >/dev/null 2>&1; then
  pass "Policy team-a-readonly đã tồn tại"
else
  fail "Policy team-a-readonly chưa được tạo — xem Bước 6 trong README"
fi

# --- Kiểm tra 7: Policy cho phép đúng path (bước 6) ------------------------
POLICY_CONTENT=$(VAULT_TOKEN=root vault policy read team-a-readonly 2>/dev/null)
if echo "$POLICY_CONTENT" | grep -q 'secret/data/team-a/\*' || \
   echo "$POLICY_CONTENT" | grep -q 'secret/data/team-a/'; then
  pass "Policy team-a-readonly chứa path secret/data/team-a/*"
else
  fail "Policy team-a-readonly không chứa path đúng (cần: secret/data/team-a/*)"
fi

# --- Kiểm tra 8 + 9: Tạo token, thử hành động được phép và bị cấm ----------
TEAM_TOKEN=$(VAULT_TOKEN=root vault token create \
  -policy=team-a-readonly \
  -ttl=1h \
  -field=token 2>/dev/null || echo "")

if [ -n "$TEAM_TOKEN" ]; then
  pass "Tạo token với policy team-a-readonly thành công"

  # Kiểm tra token có đúng policy
  TOKEN_POLICIES=$(VAULT_TOKEN=root vault token lookup -field=policies "$TEAM_TOKEN" 2>/dev/null)
  if echo "$TOKEN_POLICIES" | grep -q "team-a-readonly"; then
    pass "Token có policy team-a-readonly"
  else
    fail "Token không có policy team-a-readonly (policies hiện tại: $TOKEN_POLICIES)"
  fi

  # Hành động được phép: đọc secret tại team-a/config
  if VAULT_TOKEN="$TEAM_TOKEN" vault kv get secret/team-a/config >/dev/null 2>&1; then
    pass "Token đọc được secret/team-a/config (hành động được phép)"
  else
    fail "Token không đọc được secret/team-a/config — kiểm tra lại policy"
  fi

  # Hành động bị cấm: ghi vào secret
  if VAULT_TOKEN="$TEAM_TOKEN" vault kv put secret/team-a/config env=staging >/dev/null 2>&1; then
    fail "Token ghi được secret/team-a/config (không mong đợi — policy chỉ cho read)"
  else
    pass "Token bị từ chối khi ghi vào secret/team-a/config (đúng như mong đợi)"
  fi

  # Hành động bị cấm: đọc secret ở path khác
  if VAULT_TOKEN="$TEAM_TOKEN" vault kv get secret/other/config >/dev/null 2>&1; then
    fail "Token đọc được secret/other/config (không mong đợi — ngoài phạm vi policy)"
  else
    pass "Token bị từ chối khi đọc secret/other/config (đúng — ngoài phạm vi policy)"
  fi

  # Hành động bị cấm: xem danh sách auth methods
  if VAULT_TOKEN="$TEAM_TOKEN" vault auth list >/dev/null 2>&1; then
    fail "Token xem được vault auth list (không mong đợi — không có quyền sys/)"
  else
    pass "Token bị từ chối khi gọi vault auth list (đúng — không có quyền sys/)"
  fi

  # Thu hồi token sau khi kiểm tra xong
  VAULT_TOKEN=root vault token revoke "$TEAM_TOKEN" >/dev/null 2>&1

  # Xác nhận token đã bị thu hồi
  if VAULT_TOKEN="$TEAM_TOKEN" vault kv get secret/team-a/config >/dev/null 2>&1; then
    fail "Token sau khi revoke vẫn còn dùng được (không mong đợi)"
  else
    pass "Token sau khi revoke không còn dùng được (bước 10 đúng)"
  fi

else
  fail "Không thể tạo token với policy team-a-readonly"
  fail "Token không có policy team-a-readonly"
  fail "Token đọc được secret/team-a/config"
  fail "Token bị từ chối khi ghi vào secret"
  fail "Token bị từ chối khi đọc path khác"
  fail "Token bị từ chối khi gọi vault auth list"
  fail "Token sau khi revoke không còn dùng được"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
