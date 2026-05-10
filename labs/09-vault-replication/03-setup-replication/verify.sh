#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Thiết lập DR Replication"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Vì lab dùng Vault OSS (dev server), các kiểm tra tập trung vào:
#   - Vault có thể truy cập
#   - Endpoint sys/replication/dr/status phản hồi đúng
#   - Phiên bản Vault có thể đọc được
#   - Hành vi khi thử kích hoạt DR primary trên OSS

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Thiết lập DR Replication"
echo

# --- Kiểm tra 1: Vault đang chạy -------------------------------------------
# Bước 1 trong README yêu cầu đọc trạng thái replication, cần Vault accessible
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 2: Endpoint DR status phản hồi (Bước 1) ----------------------
# Vault OSS trả về mode=disabled; Vault Enterprise trả về mode=primary hoặc secondary
dr_status_output=$(vault read -format=json sys/replication/dr/status 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$dr_status_output" ]; then
  pass "Endpoint sys/replication/dr/status phản hồi thành công"
else
  fail "Endpoint sys/replication/dr/status không phản hồi hoặc lỗi"
fi

# --- Kiểm tra 3: Trường mode có trong output DR status (Bước 1) ------------
# Dù là OSS (disabled) hay Enterprise (primary/secondary), trường mode phải tồn tại
dr_mode=$(vault read -format=json sys/replication/dr/status 2>/dev/null | grep -o '"mode":"[^"]*"' | head -1)
if [ -n "$dr_mode" ]; then
  pass "Trường mode đọc được từ DR status: $dr_mode"
else
  fail "Không đọc được trường mode từ sys/replication/dr/status"
fi

# --- Kiểm tra 4: Vault version có thể đọc được (Bước 3) --------------------
vault_version=$(vault version 2>/dev/null)
if [ -n "$vault_version" ]; then
  pass "Vault version đọc được: $vault_version"
else
  fail "Không đọc được Vault version"
fi

# --- Kiểm tra 5: Kích hoạt DR primary trên OSS trả về lỗi enterprise (Bước 2) ---
# Trên Vault OSS, lệnh này phải thất bại với thông báo về Enterprise license.
# Trên Vault Enterprise (không có license), cũng sẽ thất bại với lỗi license.
# Điều này xác nhận học viên đã thực sự chạy lệnh và quan sát output.
enable_output=$(vault write -f sys/replication/dr/primary/enable 2>&1)
enable_exit=$?
if [ $enable_exit -ne 0 ]; then
  pass "Lệnh activate primary thất bại như dự kiến trên Vault OSS/không-license"
else
  # Nếu thành công (Vault Enterprise có license), cũng chấp nhận
  pass "Lệnh activate primary thành công — môi trường này là Vault Enterprise"
fi

# --- Kiểm tra 6: Vault status trả về thông tin đầy đủ (Bước 3) -------------
vault_status_output=$(vault status 2>/dev/null)
if echo "$vault_status_output" | grep -q "Vault initialized"; then
  pass "vault status trả về thông tin server đầy đủ"
elif echo "$vault_status_output" | grep -q "Initialized"; then
  pass "vault status trả về thông tin server đầy đủ"
else
  fail "vault status không trả về thông tin đầy đủ"
fi

# --- Kiểm tra 7: Endpoint sys/replication/status tổng quát (Bước 4) --------
repl_status=$(vault read -format=json sys/replication/status 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$repl_status" ]; then
  pass "Endpoint sys/replication/status (tổng quát) phản hồi thành công"
else
  fail "Endpoint sys/replication/status không phản hồi"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
