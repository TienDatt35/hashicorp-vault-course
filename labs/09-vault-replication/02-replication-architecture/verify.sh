#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Phân tích kiến trúc Vault Replication đa vùng
#
# Quy ước:
#   pass "mô tả ngắn"  -> in dòng [PASS]
#   fail "mô tả ngắn"  -> in dòng [FAIL] và tăng số lỗi
#
# Lưu ý quan trọng: bài này chạy trên Vault OSS dev server.
# OSS Vault luôn trả về mode=disabled cho cả DR lẫn Performance Replication —
# đây là hành vi đúng, không phải lỗi. Assertions bên dưới kiểm tra đúng
# hành vi OSS này.
#
# Mỗi assertion tương ứng với ít nhất một bước trong README.md (Bước 4).
# Exit code chỉ là 0 khi mọi kiểm tra đều đạt.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Phân tích kiến trúc Vault Replication đa vùng"
echo

# --- Kiểm tra 0: Vault có thể truy cập (tiên quyết) ----------------------------
# Vault dev server phải đang chạy trong Codespace.
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 1: sys/replication/status trả về exit code 0 (Bước 4a) ----------
# Lệnh vault read sys/replication/status phải thành công.
if vault read sys/replication/status >/dev/null 2>&1; then
  pass "vault read sys/replication/status thành công (exit code 0)"
else
  fail "vault read sys/replication/status thất bại — kiểm tra kết nối Vault"
fi

# Lưu output JSON để dùng cho các kiểm tra tiếp theo (tránh gọi API nhiều lần)
REPLICATION_STATUS=$(vault read -format=json sys/replication/status 2>/dev/null || echo '{}')

# --- Kiểm tra 2: Response có chứa thông tin về DR (Bước 4a + 4d) --------------
# Output JSON phải chứa field dr.mode — xác nhận API trả về cấu trúc đúng.
if echo "$REPLICATION_STATUS" | grep -q '"dr\.mode"'; then
  pass "Response sys/replication/status có field 'dr.mode'"
else
  fail "Response sys/replication/status thiếu field 'dr.mode' — API không trả về cấu trúc mong đợi"
fi

# --- Kiểm tra 3: Response có chứa thông tin về Performance (Bước 4a + 4d) ----
# Output JSON phải chứa field performance.mode.
if echo "$REPLICATION_STATUS" | grep -q '"performance\.mode"'; then
  pass "Response sys/replication/status có field 'performance.mode'"
else
  fail "Response sys/replication/status thiếu field 'performance.mode' — API không trả về cấu trúc mong đợi"
fi

# --- Kiểm tra 4: dr.mode là 'disabled' (Bước 4d) -----------------------------
# OSS Vault luôn trả về disabled cho DR mode — đây là hành vi đúng.
# Nếu kết quả khác disabled, nghĩa là đang chạy Vault Enterprise đã bật DR.
DR_MODE=$(echo "$REPLICATION_STATUS" \
  | grep -o '"dr\.mode":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ "$DR_MODE" = "disabled" ]; then
  pass "dr.mode = 'disabled' (hành vi đúng với Vault OSS)"
else
  fail "dr.mode = '${DR_MODE:-<không đọc được>}' (mong đợi 'disabled' trên Vault OSS)"
fi

# --- Kiểm tra 5: performance.mode là 'disabled' (Bước 4d) --------------------
# OSS Vault luôn trả về disabled cho Performance mode — đây là hành vi đúng.
PERF_MODE=$(echo "$REPLICATION_STATUS" \
  | grep -o '"performance\.mode":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ "$PERF_MODE" = "disabled" ]; then
  pass "performance.mode = 'disabled' (hành vi đúng với Vault OSS)"
else
  fail "performance.mode = '${PERF_MODE:-<không đọc được>}' (mong đợi 'disabled' trên Vault OSS)"
fi

# --- Kiểm tra 6: sys/replication/dr/status trả về exit code 0 (Bước 4b) ------
# Endpoint chi tiết cho DR phải trả về exit code 0 ngay cả trên Vault OSS.
if vault read sys/replication/dr/status >/dev/null 2>&1; then
  pass "vault read sys/replication/dr/status thành công (exit code 0)"
else
  fail "vault read sys/replication/dr/status thất bại — kiểm tra kết nối Vault"
fi

# --- Kiểm tra 7: sys/replication/performance/status trả về exit code 0 (Bước 4c)
# Endpoint chi tiết cho Performance phải trả về exit code 0 ngay cả trên Vault OSS.
if vault read sys/replication/performance/status >/dev/null 2>&1; then
  pass "vault read sys/replication/performance/status thành công (exit code 0)"
else
  fail "vault read sys/replication/performance/status thất bại — kiểm tra kết nối Vault"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
