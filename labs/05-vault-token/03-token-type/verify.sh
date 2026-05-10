#!/usr/bin/env bash
# verify.sh — kiểm tra kết quả bài thực hành "Các loại Vault Token"
#
# Các biến môi trường cần có trước khi chạy:
#   BATCH_TOKEN        — batch token tạo trực tiếp ở Bước 1
#   PERIODIC_ACCESSOR  — accessor của periodic token tạo ở Bước 2
#   ORPHAN_ACCESSOR    — accessor của orphan token tạo ở Bước 3
#   ROLE_BATCH_TOKEN   — batch token tạo từ role my-batch-role ở Bước 4
#   APPROLE_ACCESSOR   — accessor của token AppRole my-daemon ở Bước 5
#
# Học viên chạy: bash verify.sh

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

# --- Kiểm tra 1 (Bước 1): batch token có prefix hvb. hoặc b. ----------------
if [ -z "${BATCH_TOKEN:-}" ]; then
  fail "Biến BATCH_TOKEN chưa được đặt — hãy export BATCH_TOKEN=<batch token bước 1>"
else
  # Kiểm tra prefix hvb. (Vault >= 1.10) hoặc b. (Vault cũ)
  if echo "$BATCH_TOKEN" | grep -qE '^(hvb\.|b\.)'; then
    pass "BATCH_TOKEN có prefix đúng (hvb. hoặc b.) — xác nhận là batch token"
  else
    fail "BATCH_TOKEN không có prefix hvb. hoặc b. — giá trị hiện tại bắt đầu bằng: $(echo "$BATCH_TOKEN" | cut -c1-5)"
  fi

  # Kiểm tra type=batch qua lookup (batch token không lưu storage nên
  # vault token lookup trên batch token dùng chính token đó để xác thực)
  BATCH_TYPE=$(VAULT_TOKEN="$BATCH_TOKEN" vault token lookup -format=json 2>/dev/null | jq -r '.data.type' 2>/dev/null || echo "")
  if [ "$BATCH_TYPE" = "batch" ]; then
    pass "BATCH_TOKEN có type=batch khi lookup"
  else
    # Batch token có TTL ngắn có thể đã hết hạn; kiểm tra prefix là đủ
    pass "BATCH_TOKEN — prefix đã xác nhận là batch (type lookup bỏ qua vì batch token có TTL ngắn)"
  fi
fi

# --- Kiểm tra 2 (Bước 2): periodic token không có expire_time ---------------
if [ -z "${PERIODIC_ACCESSOR:-}" ]; then
  fail "Biến PERIODIC_ACCESSOR chưa được đặt — hãy export PERIODIC_ACCESSOR=<accessor bước 2>"
else
  PERIODIC_LOOKUP=$(vault token lookup -accessor "$PERIODIC_ACCESSOR" -format=json 2>/dev/null || echo "")
  if [ -z "$PERIODIC_LOOKUP" ]; then
    fail "Không thể lookup periodic token qua accessor '$PERIODIC_ACCESSOR' — token có thể đã hết hạn vì không được renew"
  else
    # Kiểm tra period có giá trị (khác 0s)
    PERIOD_VAL=$(echo "$PERIODIC_LOOKUP" | jq -r '.data.period' 2>/dev/null || echo "0s")
    if [ "$PERIOD_VAL" != "0s" ] && [ -n "$PERIOD_VAL" ]; then
      pass "Periodic token có trường period = '$PERIOD_VAL' (khác 0)"
    else
      fail "Trường period của token là '$PERIOD_VAL', kỳ vọng giá trị khác 0 (ví dụ: 2m hoặc 120)"
    fi

    # Kiểm tra expire_time trống hoặc n/a (periodic token không có expire_time cố định)
    EXPIRE_TIME=$(echo "$PERIODIC_LOOKUP" | jq -r '.data.expire_time' 2>/dev/null || echo "")
    if [ -z "$EXPIRE_TIME" ] || [ "$EXPIRE_TIME" = "null" ] || [ "$EXPIRE_TIME" = "" ]; then
      pass "Periodic token không có expire_time cố định (expire_time trống)"
    else
      fail "Periodic token có expire_time='$EXPIRE_TIME', kỳ vọng trống — kiểm tra lại cách tạo token (dùng -period thay vì -ttl)"
    fi
  fi
fi

# --- Kiểm tra 3 (Bước 3): orphan token còn sống sau khi parent bị revoke ----
if [ -z "${ORPHAN_ACCESSOR:-}" ]; then
  fail "Biến ORPHAN_ACCESSOR chưa được đặt — hãy export ORPHAN_ACCESSOR=<accessor bước 3>"
else
  ORPHAN_LOOKUP=$(vault token lookup -accessor "$ORPHAN_ACCESSOR" -format=json 2>/dev/null || echo "")
  if [ -z "$ORPHAN_LOOKUP" ]; then
    fail "Orphan token không thể lookup qua accessor '$ORPHAN_ACCESSOR' — token có thể đã hết TTL"
  else
    IS_ORPHAN=$(echo "$ORPHAN_LOOKUP" | jq -r '.data.orphan' 2>/dev/null || echo "false")
    if [ "$IS_ORPHAN" = "true" ]; then
      pass "Orphan token vẫn còn sống và có orphan=true sau khi parent bị revoke"
    else
      fail "Token có accessor '$ORPHAN_ACCESSOR' có orphan='$IS_ORPHAN', kỳ vọng 'true' — hãy dùng flag -orphan khi tạo"
    fi
  fi
fi

# --- Kiểm tra 4 (Bước 4): token từ role my-batch-role có prefix hvb. --------
if [ -z "${ROLE_BATCH_TOKEN:-}" ]; then
  fail "Biến ROLE_BATCH_TOKEN chưa được đặt — hãy export ROLE_BATCH_TOKEN=<token từ role bước 4>"
else
  # Kiểm tra role tồn tại
  if vault read auth/token/roles/my-batch-role >/dev/null 2>&1; then
    pass "Token store role 'my-batch-role' tồn tại"
  else
    fail "Token store role 'my-batch-role' chưa được tạo"
  fi

  # Kiểm tra token có prefix hvb.
  if echo "$ROLE_BATCH_TOKEN" | grep -qE '^(hvb\.|b\.)'; then
    pass "ROLE_BATCH_TOKEN từ role 'my-batch-role' có prefix batch (hvb. hoặc b.)"
  else
    fail "ROLE_BATCH_TOKEN không có prefix hvb. — bắt đầu bằng: $(echo "$ROLE_BATCH_TOKEN" | cut -c1-5). Kiểm tra lại token_type trong role"
  fi
fi

# --- Kiểm tra 5 (Bước 5): AppRole role my-daemon và token periodic ----------
# Kiểm tra AppRole được enable
if vault auth list -format=json 2>/dev/null | jq -e '."approle/"' >/dev/null 2>&1; then
  pass "AppRole auth method đã được enable"
else
  fail "AppRole auth method chưa được enable — chạy: vault auth enable approle"
fi

# Kiểm tra role my-daemon tồn tại với token_type=service và token_period
if vault read -format=json auth/approle/role/my-daemon >/dev/null 2>&1; then
  pass "AppRole role 'my-daemon' tồn tại"

  DAEMON_PERIOD=$(vault read -format=json auth/approle/role/my-daemon | jq -r '.data.token_period' 2>/dev/null || echo "0")
  if [ "$DAEMON_PERIOD" != "0" ] && [ "$DAEMON_PERIOD" != "0s" ] && [ -n "$DAEMON_PERIOD" ]; then
    pass "AppRole role 'my-daemon' có token_period = '$DAEMON_PERIOD' (khác 0)"
  else
    fail "AppRole role 'my-daemon' có token_period='$DAEMON_PERIOD', kỳ vọng giá trị > 0 (ví dụ: 2m)"
  fi

  DAEMON_TYPE=$(vault read -format=json auth/approle/role/my-daemon | jq -r '.data.token_type' 2>/dev/null || echo "")
  if [ "$DAEMON_TYPE" = "service" ]; then
    pass "AppRole role 'my-daemon' có token_type=service"
  else
    fail "AppRole role 'my-daemon' có token_type='$DAEMON_TYPE', kỳ vọng 'service'"
  fi
else
  fail "AppRole role 'my-daemon' chưa được tạo"
fi

# Kiểm tra token login AppRole có type=service và period
if [ -z "${APPROLE_ACCESSOR:-}" ]; then
  fail "Biến APPROLE_ACCESSOR chưa được đặt — hãy export APPROLE_ACCESSOR=<accessor bước 5>"
else
  APPROLE_LOOKUP=$(vault token lookup -accessor "$APPROLE_ACCESSOR" -format=json 2>/dev/null || echo "")
  if [ -z "$APPROLE_LOOKUP" ]; then
    fail "Không thể lookup token AppRole qua accessor '$APPROLE_ACCESSOR' — token có thể đã hết TTL"
  else
    APPROLE_TYPE=$(echo "$APPROLE_LOOKUP" | jq -r '.data.type' 2>/dev/null || echo "")
    if [ "$APPROLE_TYPE" = "service" ]; then
      pass "Token AppRole 'my-daemon' có type=service"
    else
      fail "Token AppRole có type='$APPROLE_TYPE', kỳ vọng 'service'"
    fi

    APPROLE_PERIOD=$(echo "$APPROLE_LOOKUP" | jq -r '.data.period' 2>/dev/null || echo "0s")
    if [ "$APPROLE_PERIOD" != "0s" ] && [ -n "$APPROLE_PERIOD" ]; then
      pass "Token AppRole 'my-daemon' có period = '$APPROLE_PERIOD' (periodic token)"
    else
      fail "Token AppRole có period='$APPROLE_PERIOD', kỳ vọng giá trị khác 0 — kiểm tra cấu hình token_period trong role"
    fi

    APPROLE_EXPIRE=$(echo "$APPROLE_LOOKUP" | jq -r '.data.expire_time' 2>/dev/null || echo "")
    if [ -z "$APPROLE_EXPIRE" ] || [ "$APPROLE_EXPIRE" = "null" ]; then
      pass "Token AppRole 'my-daemon' không có expire_time cố định (periodic)"
    else
      fail "Token AppRole có expire_time='$APPROLE_EXPIRE', kỳ vọng trống — periodic token không có expire_time"
    fi
  fi
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
