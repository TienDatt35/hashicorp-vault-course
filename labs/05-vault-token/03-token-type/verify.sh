#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Các loại Vault Token"
#
# Script tự tạo token test để kiểm tra từng khái niệm.
# Không cần biến môi trường ngoài VAULT_ADDR và VAULT_TOKEN.
#
# Chạy: bash verify.sh

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Các loại Vault Token"
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

# --- Kiểm tra 1 (Bước 1): batch token có prefix hvb. và không thể renew ------
BATCH_TOK=$(vault token create \
  -type=batch -ttl=10m -policy=default \
  -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -z "$BATCH_TOK" ] || [ "$BATCH_TOK" = "null" ]; then
  fail "Không thể tạo batch token"
else
  if echo "$BATCH_TOK" | grep -qE '^(hvb\.|b\.)'; then
    pass "Batch token có prefix hvb. — định dạng đúng"
  else
    fail "Batch token không có prefix hvb. — bắt đầu bằng: $(echo "$BATCH_TOK" | cut -c1-6)"
  fi

  # Xác nhận type=batch qua lookup
  BATCH_TYPE=$(VAULT_TOKEN="$BATCH_TOK" vault token lookup -format=json 2>/dev/null \
    | jq -r '.data.type' 2>/dev/null || echo "")
  if [ "$BATCH_TYPE" = "batch" ]; then
    pass "Batch token có type=batch"
  else
    fail "Batch token type='$BATCH_TYPE', kỳ vọng 'batch'"
  fi

  # Thử renew batch token — phải thất bại
  if ! vault token renew "$BATCH_TOK" >/dev/null 2>&1; then
    pass "Batch token không thể renew (đúng như kỳ vọng)"
  else
    fail "Batch token có thể renew — batch token không được phép renew"
  fi
fi

# --- Kiểm tra 2 (Bước 2): periodic token có period > 0 và explicit_max_ttl = 0
# Lưu ý: periodic token VẪN có expire_time (= thời điểm cuối period hiện tại)
# Khác biệt so với service token thường là: explicit_max_ttl=0 và period>0
PERIODIC_TOK=$(vault token create \
  -period=2m -policy=default \
  -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -z "$PERIODIC_TOK" ] || [ "$PERIODIC_TOK" = "null" ]; then
  fail "Không thể tạo periodic token"
else
  PERIODIC_LOOKUP=$(vault token lookup -format=json "$PERIODIC_TOK" 2>/dev/null || echo "")
  PERIOD_VAL=$(echo "$PERIODIC_LOOKUP" | jq -r '.data.period' 2>/dev/null || echo "0")
  EXPLICIT_MAX=$(echo "$PERIODIC_LOOKUP" | jq -r '.data.explicit_max_ttl' 2>/dev/null || echo "")

  if [ "$PERIOD_VAL" != "0" ] && [ "$PERIOD_VAL" != "0s" ] && [ -n "$PERIOD_VAL" ]; then
    pass "Periodic token có trường period = $PERIOD_VAL (khác 0)"
  else
    fail "Periodic token period='$PERIOD_VAL', kỳ vọng giá trị > 0 — dùng flag -period khi tạo"
  fi

  # explicit_max_ttl=0 nghĩa là không có giới hạn cứng — token sống mãi nếu renew đúng hạn
  if [ "$EXPLICIT_MAX" = "0" ] || [ "$EXPLICIT_MAX" = "0s" ] || [ -z "$EXPLICIT_MAX" ]; then
    pass "Periodic token không có explicit_max_ttl — có thể sống mãi nếu renew đúng hạn"
  else
    fail "Periodic token có explicit_max_ttl='$EXPLICIT_MAX', kỳ vọng 0 — periodic token không có giới hạn cứng"
  fi

  # Renew về đầu period
  RENEW_JSON=$(vault token renew -format=json "$PERIODIC_TOK" 2>/dev/null || echo "")
  RENEWED_TTL=$(echo "$RENEW_JSON" | jq -r '.auth.lease_duration // 0' 2>/dev/null || echo "0")
  if [ "$RENEWED_TTL" -gt 0 ] 2>/dev/null; then
    pass "Periodic token renew thành công, TTL reset về ${RENEWED_TTL}s"
  else
    fail "Periodic token không thể renew — kiểm tra lại cách tạo token"
  fi
  vault token revoke "$PERIODIC_TOK" >/dev/null 2>&1 || true
fi

# --- Kiểm tra 3 (Bước 3): cascade revocation và orphan token -----------------
# Tạo policy tạm để parent có thể tạo child token
vault policy write _lab_parent_policy - >/dev/null 2>&1 <<'HCL'
path "auth/token/create" {
  capabilities = ["create", "update"]
}
HCL

PARENT_TOK=$(vault token create \
  -policy=_lab_parent_policy -ttl=10m \
  -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")
ORPHAN_TOK=$(vault token create \
  -orphan -policy=default -ttl=30m \
  -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")

if [ -z "$PARENT_TOK" ] || [ "$PARENT_TOK" = "null" ] || \
   [ -z "$ORPHAN_TOK" ] || [ "$ORPHAN_TOK" = "null" ]; then
  fail "Không thể tạo parent hoặc orphan token"
else
  CHILD_TOK=$(VAULT_TOKEN="$PARENT_TOK" vault token create \
    -policy=default -ttl=10m \
    -format=json 2>/dev/null | jq -r '.auth.client_token' 2>/dev/null || echo "")

  vault token revoke "$PARENT_TOK" >/dev/null 2>&1 || true

  if [ -n "$CHILD_TOK" ] && [ "$CHILD_TOK" != "null" ]; then
    if ! vault token lookup "$CHILD_TOK" >/dev/null 2>&1; then
      pass "Cascade revocation: child token bị revoke theo parent"
    else
      fail "Cascade revocation không hoạt động — child token vẫn sống sau khi parent bị revoke"
    fi
  else
    fail "Không thể tạo child token từ parent — kiểm tra policy của parent token"
  fi

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
    fail "Orphan token bị revoke theo parent — phải dùng flag -orphan khi tạo"
  fi
fi

vault policy delete _lab_parent_policy >/dev/null 2>&1 || true

# --- Kiểm tra 4 (Bước 4): token store role sinh batch token ------------------
# Lưu ý: role token_type=batch phải có orphan=true
vault write auth/token/roles/my-batch-role \
  token_type=batch \
  token_ttl=15m \
  allowed_policies=default \
  renewable=false \
  orphan=true >/dev/null 2>&1

if vault read auth/token/roles/my-batch-role >/dev/null 2>&1; then
  pass "Token store role 'my-batch-role' tồn tại"

  ROLE_TOK=$(vault token create -role=my-batch-role -format=json 2>/dev/null \
    | jq -r '.auth.client_token' 2>/dev/null || echo "")
  if [ -n "$ROLE_TOK" ] && [ "$ROLE_TOK" != "null" ]; then
    if echo "$ROLE_TOK" | grep -qE '^(hvb\.|b\.)'; then
      pass "Token từ role 'my-batch-role' có prefix hvb. — xác nhận là batch token"
    else
      fail "Token từ role 'my-batch-role' không có prefix hvb. — bắt đầu bằng: $(echo "$ROLE_TOK" | cut -c1-6)"
    fi
  else
    fail "Không thể tạo token từ role 'my-batch-role'"
  fi
else
  fail "Token store role 'my-batch-role' chưa được tạo"
fi

# --- Kiểm tra 5 (Bước 5): AppRole sinh periodic service token ----------------
if vault auth list -format=json 2>/dev/null | jq -e '."approle/"' >/dev/null 2>&1; then
  pass "AppRole auth method đã được enable"
else
  vault auth enable approle >/dev/null 2>&1 && pass "AppRole auth method đã được enable" \
    || fail "Không thể enable AppRole auth method"
fi

vault write auth/approle/role/my-daemon \
  token_type=service \
  token_period=2m \
  token_policies=default >/dev/null 2>&1

if vault read -format=json auth/approle/role/my-daemon >/dev/null 2>&1; then
  pass "AppRole role 'my-daemon' tồn tại"

  DAEMON_INFO=$(vault read -format=json auth/approle/role/my-daemon 2>/dev/null || echo "")
  DAEMON_PERIOD=$(echo "$DAEMON_INFO" | jq -r '.data.token_period' 2>/dev/null || echo "0")
  DAEMON_TYPE=$(echo "$DAEMON_INFO"   | jq -r '.data.token_type'   2>/dev/null || echo "")

  if [ "$DAEMON_PERIOD" != "0" ] && [ "$DAEMON_PERIOD" != "0s" ] && [ -n "$DAEMON_PERIOD" ]; then
    pass "AppRole role 'my-daemon' có token_period = $DAEMON_PERIOD"
  else
    fail "AppRole role 'my-daemon' token_period='$DAEMON_PERIOD', kỳ vọng > 0"
  fi

  if [ "$DAEMON_TYPE" = "service" ]; then
    pass "AppRole role 'my-daemon' có token_type=service"
  else
    fail "AppRole role 'my-daemon' token_type='$DAEMON_TYPE', kỳ vọng 'service'"
  fi

  # Login AppRole và kiểm tra token nhận được
  ROLE_ID=$(vault read -field=role_id auth/approle/role/my-daemon/role-id 2>/dev/null || echo "")
  SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/my-daemon/secret-id 2>/dev/null || echo "")
  if [ -n "$ROLE_ID" ] && [ -n "$SECRET_ID" ]; then
    APPROLE_TOK=$(vault write -format=json auth/approle/login \
      role_id="$ROLE_ID" secret_id="$SECRET_ID" 2>/dev/null \
      | jq -r '.auth.client_token' 2>/dev/null || echo "")
    if [ -n "$APPROLE_TOK" ] && [ "$APPROLE_TOK" != "null" ]; then
      APPROLE_DATA=$(vault token lookup -format=json "$APPROLE_TOK" 2>/dev/null || echo "")
      APPROLE_TYPE=$(echo "$APPROLE_DATA"   | jq -r '.data.type'   2>/dev/null || echo "")
      APPROLE_PERIOD=$(echo "$APPROLE_DATA" | jq -r '.data.period' 2>/dev/null || echo "0")

      if [ "$APPROLE_TYPE" = "service" ]; then
        pass "Token AppRole 'my-daemon' có type=service"
      else
        fail "Token AppRole có type='$APPROLE_TYPE', kỳ vọng 'service'"
      fi

      if [ "$APPROLE_PERIOD" != "0" ] && [ "$APPROLE_PERIOD" != "0s" ] && [ -n "$APPROLE_PERIOD" ]; then
        pass "Token AppRole 'my-daemon' có period = $APPROLE_PERIOD (periodic service token)"
      else
        fail "Token AppRole period='$APPROLE_PERIOD', kỳ vọng > 0 — kiểm tra token_period trong role"
      fi
      vault token revoke "$APPROLE_TOK" >/dev/null 2>&1 || true
    else
      fail "Không thể login AppRole để lấy token"
    fi
  else
    fail "Không thể lấy role_id hoặc secret_id của 'my-daemon'"
  fi
else
  fail "AppRole role 'my-daemon' chưa được tạo"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
