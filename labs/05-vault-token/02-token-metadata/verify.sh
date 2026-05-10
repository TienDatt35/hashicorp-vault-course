#!/usr/bin/env bash
# verify.sh — kiểm tra kết quả bài thực hành "Phân tích Token Metadata"
#
# Các biến môi trường cần có trước khi chạy:
#   LAB_ACCESSOR       — accessor của token tạo ở Bước 2 (display_name=lab-user, meta env=lab)
#   MAX_TTL_ACCESSOR   — accessor của token tạo ở Bước 3 (explicit_max_ttl=5m)
#   ORPHAN_ACCESSOR    — accessor của orphan token tạo ở Bước 5
#
# Học viên chạy: bash verify.sh

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

# --- Kiểm tra 2 (Bước 2): token lab-user tồn tại và có đúng display_name ---
if [ -z "${LAB_ACCESSOR:-}" ]; then
  fail "Biến LAB_ACCESSOR chưa được đặt — hãy export LAB_ACCESSOR=<accessor bước 2>"
else
  # Lookup bằng accessor và kiểm tra display_name
  LAB_LOOKUP=$(vault token lookup -accessor "$LAB_ACCESSOR" -format=json 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$LAB_LOOKUP" ]; then
    fail "Không thể lookup token bước 2 qua accessor '$LAB_ACCESSOR' — token có thể đã bị revoke"
  else
    DISPLAY_NAME=$(echo "$LAB_LOOKUP" | jq -r '.data.display_name' 2>/dev/null || echo "")
    if [ "$DISPLAY_NAME" = "token-lab-user" ] || echo "$DISPLAY_NAME" | grep -qi "lab-user"; then
      pass "Token bước 2 có display_name chứa 'lab-user'"
    else
      fail "display_name của token bước 2 là '$DISPLAY_NAME', kỳ vọng chứa 'lab-user'"
    fi

    # Kiểm tra metadata env=lab
    META_ENV=$(echo "$LAB_LOOKUP" | jq -r '.data.meta.env' 2>/dev/null || echo "")
    if [ "$META_ENV" = "lab" ]; then
      pass "Token bước 2 có meta.env = 'lab'"
    else
      fail "meta.env của token bước 2 là '$META_ENV', kỳ vọng 'lab'"
    fi
  fi
fi

# --- Kiểm tra 3 (Bước 3): token explicit_max_ttl được tạo đúng -------------
if [ -z "${MAX_TTL_ACCESSOR:-}" ]; then
  fail "Biến MAX_TTL_ACCESSOR chưa được đặt — hãy export MAX_TTL_ACCESSOR=<accessor bước 3>"
else
  MAX_TTL_LOOKUP=$(vault token lookup -accessor "$MAX_TTL_ACCESSOR" -format=json 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$MAX_TTL_LOOKUP" ]; then
    fail "Không thể lookup token bước 3 qua accessor '$MAX_TTL_ACCESSOR'"
  else
    # Kiểm tra explicit_max_ttl được đặt (giá trị > 0)
    EXPLICIT_MAX=$(echo "$MAX_TTL_LOOKUP" | jq -r '.data.explicit_max_ttl' 2>/dev/null || echo "0")
    if [ "$EXPLICIT_MAX" != "0" ] && [ "$EXPLICIT_MAX" != "0s" ] && [ -n "$EXPLICIT_MAX" ]; then
      pass "Token bước 3 có explicit_max_ttl = '$EXPLICIT_MAX' (khác 0)"
    else
      fail "explicit_max_ttl của token bước 3 là '$EXPLICIT_MAX', kỳ vọng giá trị > 0 (ví dụ: 5m hoặc 300)"
    fi
  fi
fi

# --- Kiểm tra 4 (Bước 4): token use-limit đã bị revoke tự động -------------
# Để kiểm tra, học viên cần đã thực hiện đủ 3 lần lookup làm cạn kiệt use.
# verify.sh không thể biết token ID vì token đã bị revoke.
# Ta kiểm tra gián tiếp bằng cách yêu cầu học viên xác nhận qua file tạm.
USE_LIMIT_CONFIRM_FILE="/tmp/vault_lab_use_limit_done"
if [ -f "$USE_LIMIT_CONFIRM_FILE" ]; then
  pass "Bước 4 đã được xác nhận hoàn thành (file $USE_LIMIT_CONFIRM_FILE tồn tại)"
else
  # Thử kiểm tra thêm: nếu học viên để lại USE_TOKEN trong môi trường
  if [ -n "${USE_TOKEN:-}" ]; then
    if ! vault token lookup "$USE_TOKEN" >/dev/null 2>&1; then
      pass "Token use-limit đã bị revoke sau khi dùng hết 3 lần"
    else
      fail "Token use-limit vẫn còn hoạt động — hãy thực hiện đủ 3 lần lookup trên token đó"
    fi
  else
    fail "Bước 4 chưa được xác nhận. Sau khi dùng hết use-limit, chạy: touch $USE_LIMIT_CONFIRM_FILE"
  fi
fi

# --- Kiểm tra 5 (Bước 5): orphan token còn sống sau khi parent bị revoke ---
if [ -z "${ORPHAN_ACCESSOR:-}" ]; then
  fail "Biến ORPHAN_ACCESSOR chưa được đặt — hãy export ORPHAN_ACCESSOR=<accessor bước 5>"
else
  ORPHAN_LOOKUP=$(vault token lookup -accessor "$ORPHAN_ACCESSOR" -format=json 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$ORPHAN_LOOKUP" ]; then
    fail "Orphan token không thể lookup — có thể đã bị revoke hoặc hết TTL"
  else
    # Xác nhận token là orphan
    IS_ORPHAN=$(echo "$ORPHAN_LOOKUP" | jq -r '.data.orphan' 2>/dev/null || echo "false")
    if [ "$IS_ORPHAN" = "true" ]; then
      pass "Orphan token vẫn còn sống và có orphan=true"
    else
      fail "Token có accessor '$ORPHAN_ACCESSOR' có orphan='$IS_ORPHAN', kỳ vọng 'true'"
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
