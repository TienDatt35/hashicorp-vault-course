#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Chọn Token Phù Hợp — Best Practice"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Mỗi bước trong README.md có ít nhất một assertion tương ứng ở đây.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Chọn Token Phù Hợp — Best Practice"
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

# --- Kiểm tra 1: Policy best-practice-policy tồn tại (Bước 1) ---------------
if vault policy read best-practice-policy >/dev/null 2>&1; then
  pass "Policy 'best-practice-policy' tồn tại"
else
  fail "Policy 'best-practice-policy' chưa được tạo"
fi

# --- Kiểm tra 2: Periodic token có period trong metadata (Bước 2) ------------
# Tạo một periodic token mới để kiểm tra — không yêu cầu học viên lưu token
PERIODIC_CHECK=$(vault token create \
  -policy=best-practice-policy \
  -period=1h \
  -format=json 2>/dev/null)

if [ -n "$PERIODIC_CHECK" ]; then
  PERIODIC_TOKEN_VAL=$(echo "$PERIODIC_CHECK" | jq -r '.auth.client_token' 2>/dev/null)
  PERIOD_VAL=$(vault token lookup -format=json "$PERIODIC_TOKEN_VAL" 2>/dev/null \
    | jq -r '.data.period' 2>/dev/null)

  if [ "$PERIOD_VAL" != "null" ] && [ "$PERIOD_VAL" != "" ] && [ "$PERIOD_VAL" -gt 0 ] 2>/dev/null; then
    pass "Periodic token có period=${PERIOD_VAL}s trong metadata"
  else
    fail "Periodic token không có trường 'period' hợp lệ trong metadata"
  fi

  # Dọn dẹp token vừa tạo để kiểm tra
  vault token revoke "$PERIODIC_TOKEN_VAL" >/dev/null 2>&1 || true
else
  fail "Không tạo được periodic token để kiểm tra — kiểm tra policy best-practice-policy"
fi

# --- Kiểm tra 3: Use-limit token có num_uses=3 (Bước 3) ---------------------
USE_LIMIT_CHECK=$(vault token create \
  -policy=best-practice-policy \
  -use-limit=3 \
  -ttl=1h \
  -format=json 2>/dev/null)

if [ -n "$USE_LIMIT_CHECK" ]; then
  USE_LIMIT_TOKEN_VAL=$(echo "$USE_LIMIT_CHECK" | jq -r '.auth.client_token' 2>/dev/null)
  NUM_USES=$(vault token lookup -format=json "$USE_LIMIT_TOKEN_VAL" 2>/dev/null \
    | jq -r '.data.num_uses' 2>/dev/null)

  # Lưu ý: lookup tiêu thụ 1 lần dùng, nên num_uses ban đầu là 3 nhưng sau lookup còn 2
  if [ "$NUM_USES" = "2" ] || [ "$NUM_USES" = "3" ]; then
    pass "Use-limit token có num_uses hợp lệ (${NUM_USES} còn lại sau lookup)"
  else
    fail "Use-limit token không có num_uses như kỳ vọng (nhận được: ${NUM_USES:-không xác định})"
  fi

  # Dọn dẹp
  vault token revoke "$USE_LIMIT_TOKEN_VAL" >/dev/null 2>&1 || true
else
  fail "Không tạo được use-limit token để kiểm tra"
fi

# --- Kiểm tra 4: Orphan token có orphan=true (Bước 4) -----------------------
ORPHAN_CHECK=$(vault token create \
  -policy=best-practice-policy \
  -orphan \
  -ttl=1h \
  -format=json 2>/dev/null)

if [ -n "$ORPHAN_CHECK" ]; then
  ORPHAN_TOKEN_VAL=$(echo "$ORPHAN_CHECK" | jq -r '.auth.client_token' 2>/dev/null)
  ORPHAN_VAL=$(vault token lookup -format=json "$ORPHAN_TOKEN_VAL" 2>/dev/null \
    | jq -r '.data.orphan' 2>/dev/null)

  if [ "$ORPHAN_VAL" = "true" ]; then
    pass "Orphan token có orphan=true trong metadata"
  else
    fail "Orphan token không có orphan=true trong metadata (nhận được: ${ORPHAN_VAL:-không xác định})"
  fi

  # Dọn dẹp
  vault token revoke "$ORPHAN_TOKEN_VAL" >/dev/null 2>&1 || true
else
  fail "Không tạo được orphan token để kiểm tra"
fi

# --- Kiểm tra 5: Batch token renewal trả về lỗi (Bước 5) -------------------
BATCH_CHECK=$(vault token create \
  -policy=best-practice-policy \
  -type=batch \
  -ttl=1h \
  -format=json 2>/dev/null)

if [ -n "$BATCH_CHECK" ]; then
  BATCH_TOKEN_VAL=$(echo "$BATCH_CHECK" | jq -r '.auth.client_token' 2>/dev/null)

  # Thử renew batch token — phải thất bại
  if vault token renew "$BATCH_TOKEN_VAL" >/dev/null 2>&1; then
    fail "Batch token renew thành công — đây là hành vi không mong đợi (batch token không thể renew)"
  else
    pass "Batch token renewal trả về lỗi như kỳ vọng (batch token không thể renew)"
  fi
else
  fail "Không tạo được batch token để kiểm tra"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
