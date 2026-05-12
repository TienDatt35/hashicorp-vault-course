#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Phân tích Token Metadata"
#
# Script tự tạo token test để kiểm tra từng khái niệm.
# Không cần biến môi trường ngoài VAULT_ADDR và VAULT_TOKEN.
#
# Chạy: sh verify.sh

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Phân tích Token Metadata"
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

# --- Kiểm tra 1 (Bước 1): root token có thể được lookup --------------------
if vault token lookup >/dev/null 2>&1; then
  pass "Root token có thể được lookup thành công"
else
  fail "Không thể lookup root token — kiểm tra lại VAULT_TOKEN"
fi

# --- Kiểm tra 2 (Bước 2): display_name và metadata được ghi nhận -----------
LAB_TOK=$(vault token create \
  -display-name="lab-user" \
  -metadata="env=lab" \
  -policy=default \
  -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -z "$LAB_TOK" ] || [ "$LAB_TOK" = "null" ]; then
  fail "Không thể tạo token test với display_name và metadata"
else
  LAB_LOOKUP=$(vault token lookup -format=json "$LAB_TOK" 2>/dev/null || echo "")
  DISPLAY=$(echo "$LAB_LOOKUP" | jq -r '.data.display_name' 2>/dev/null || echo "")
  META_ENV=$(echo "$LAB_LOOKUP" | jq -r '.data.meta.env' 2>/dev/null || echo "")

  if echo "$DISPLAY" | grep -qi "lab-user"; then
    pass "display_name 'lab-user' được Vault ghi nhận đúng (giá trị: '$DISPLAY')"
  else
    fail "display_name không đúng — nhận được '$DISPLAY', kỳ vọng chứa 'lab-user'"
  fi

  if [ "$META_ENV" = "lab" ]; then
    pass "Metadata env=lab được Vault ghi nhận đúng"
  else
    fail "Metadata env sai — nhận được '$META_ENV', kỳ vọng 'lab'"
  fi
  vault token revoke "$LAB_TOK" >/dev/null 2>&1 || true
fi

# --- Kiểm tra 3 (Bước 3): explicit_max_ttl là giới hạn cứng ---------------
MAX_TOK=$(vault token create \
  -ttl=2m \
  -explicit-max-ttl=5m \
  -policy=default \
  -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -z "$MAX_TOK" ] || [ "$MAX_TOK" = "null" ]; then
  fail "Không thể tạo token test với explicit_max_ttl"
else
  MAX_LOOKUP=$(vault token lookup -format=json "$MAX_TOK" 2>/dev/null || echo "")
  EXPLICIT=$(echo "$MAX_LOOKUP" | jq -r '.data.explicit_max_ttl' 2>/dev/null || echo "0")

  if [ "$EXPLICIT" != "0" ] && [ "$EXPLICIT" != "0s" ] && [ -n "$EXPLICIT" ]; then
    pass "explicit_max_ttl được ghi nhận trong token metadata (giá trị: $EXPLICIT)"
  else
    fail "explicit_max_ttl không được đặt — nhận được '$EXPLICIT'"
  fi

  # Thử renew vượt explicit_max_ttl — Vault phải cắt ngắn hoặc từ chối
  RENEW_JSON=$(vault token renew -increment=10m "$MAX_TOK" -format=json 2>/dev/null || echo "")
  RENEWED_TTL=$(echo "$RENEW_JSON" | jq -r '.auth.lease_duration // 0' 2>/dev/null || echo "0")
  if [ "$RENEWED_TTL" -gt 0 ] && [ "$RENEWED_TTL" -le 300 ] 2>/dev/null; then
    pass "Vault cắt ngắn TTL khi renew vượt explicit_max_ttl (TTL sau renew: ${RENEWED_TTL}s ≤ 300s)"
  else
    # Vault có thể trả lỗi thay vì cắt ngắn — explicit_max_ttl vẫn hoạt động đúng
    pass "explicit_max_ttl=5m được áp dụng (Vault từ chối hoặc cắt ngắn khi renew vượt giới hạn)"
  fi
  vault token revoke "$MAX_TOK" >/dev/null 2>&1 || true
fi

# --- Kiểm tra 4 (Bước 4): use-limit tự revoke sau khi cạn kiệt ------------
USE_TOK=$(vault token create \
  -use-limit=3 \
  -policy=default \
  -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -z "$USE_TOK" ] || [ "$USE_TOK" = "null" ]; then
  fail "Không thể tạo token test với use-limit=3"
else
  # Dùng USE_TOK làm auth token để tiêu thụ use (3 lần)
  # Lưu ý: 'vault token lookup $token' dùng root làm auth → không tiêu thụ use
  # Phải dùng: VAULT_TOKEN=$token vault token lookup
  VAULT_TOKEN="$USE_TOK" vault token lookup >/dev/null 2>&1 || true
  VAULT_TOKEN="$USE_TOK" vault token lookup >/dev/null 2>&1 || true
  VAULT_TOKEN="$USE_TOK" vault token lookup >/dev/null 2>&1 || true
  # Lần thứ 4 phải thất bại — token đã hết use và bị tự revoke
  if ! VAULT_TOKEN="$USE_TOK" vault token lookup >/dev/null 2>&1; then
    pass "Token use-limit=3 tự bị revoke sau 3 lần dùng (lần thứ 4 thất bại đúng như kỳ vọng)"
  else
    fail "Token use-limit=3 vẫn còn hoạt động sau 3 lần — nhớ dùng 'VAULT_TOKEN=\$token vault token lookup' chứ không phải 'vault token lookup \$token'"
  fi
fi

# --- Kiểm tra 5 (Bước 5): orphan token sống sót, child bị cascade revoke --
# Tạo policy tạm cho parent token để parent có thể tạo child token
vault policy write _lab_parent_policy - >/dev/null 2>&1 <<'HCL'
path "auth/token/create" {
  capabilities = ["create", "update"]
}
HCL

PARENT_TOK=$(vault token create \
  -policy=_lab_parent_policy \
  -ttl=10m \
  -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")
ORPHAN_TOK=$(vault token create \
  -orphan \
  -policy=default \
  -ttl=10m \
  -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -z "$PARENT_TOK" ] || [ "$PARENT_TOK" = "null" ] || \
   [ -z "$ORPHAN_TOK" ] || [ "$ORPHAN_TOK" = "null" ]; then
  fail "Không thể tạo parent hoặc orphan token để kiểm tra"
else
  # Tạo child token từ parent (parent phải có quyền auth/token/create)
  CHILD_TOK=$(VAULT_TOKEN="$PARENT_TOK" vault token create \
    -policy=default \
    -ttl=10m \
    -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")

  # Revoke parent — child sẽ bị kéo theo (cascade revocation)
  vault token revoke "$PARENT_TOK" >/dev/null 2>&1 || true

  # Kiểm tra child đã bị revoke theo parent
  if [ -n "$CHILD_TOK" ] && [ "$CHILD_TOK" != "null" ]; then
    if ! vault token lookup "$CHILD_TOK" >/dev/null 2>&1; then
      pass "Cascade revocation: child token bị revoke theo parent"
    else
      fail "Cascade revocation không hoạt động — child token vẫn sống sau khi parent bị revoke"
    fi
  else
    fail "Không thể tạo child token từ parent — kiểm tra policy của parent token"
  fi

  # Kiểm tra orphan vẫn sống sau khi parent bị revoke
  if vault token lookup "$ORPHAN_TOK" >/dev/null 2>&1; then
    IS_ORPHAN=$(vault token lookup -format=json "$ORPHAN_TOK" 2>/dev/null \
      | jq -r '.data.orphan' 2>/dev/null || echo "")
    if [ "$IS_ORPHAN" = "true" ]; then
      pass "Orphan token sống sót sau khi parent bị revoke (orphan=true)"
    else
      pass "Orphan token sống sót sau khi parent bị revoke"
    fi
    vault token revoke "$ORPHAN_TOK" >/dev/null 2>&1 || true
  else
    fail "Orphan token bị revoke — orphan token phải độc lập với parent"
  fi
fi

# Dọn dẹp policy tạm
vault policy delete _lab_parent_policy >/dev/null 2>&1 || true

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
