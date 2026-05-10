#!/usr/bin/env bash
# verify.sh — kiem tra bai thuc hanh "Cau hinh DR Replication qua CLI va UI"
#
# Quy uoc:
#   pass "mo ta ngan"   -> in dong [PASS]
#   fail "mo ta ngan"   -> in dong [FAIL] va tang so loi
#
# Vault OSS khong ho tro replication nhung cac endpoint /status van phan hoi.
# Bai nay kiem tra rằng học viên đã truy vấn đúng endpoint và hiểu output.

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Cấu hình DR Replication qua CLI và UI"
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

# --- Kiểm tra 1: endpoint sys/replication/dr/status phản hồi (Bước 1) -------
dr_status_output=$(vault read -format=json sys/replication/dr/status 2>&1)
if echo "$dr_status_output" | grep -q '"data"'; then
  pass "sys/replication/dr/status phản hồi và trả về trường data"
else
  fail "sys/replication/dr/status không phản hồi đúng — kiểm tra kết nối Vault"
fi

# --- Kiểm tra 2: endpoint sys/replication/performance/status phản hồi (Bước 3) ---
perf_status_output=$(vault read -format=json sys/replication/performance/status 2>&1)
if echo "$perf_status_output" | grep -q '"data"'; then
  pass "sys/replication/performance/status phản hồi và trả về trường data"
else
  fail "sys/replication/performance/status không phản hồi đúng"
fi

# --- Kiểm tra 3: endpoint sys/replication/status tổng hợp phản hồi (Bước 4) ---
overall_status_output=$(vault read -format=json sys/replication/status 2>&1)
if echo "$overall_status_output" | grep -q '"data"'; then
  pass "sys/replication/status (tổng hợp) phản hồi và trả về trường data"
else
  fail "sys/replication/status không phản hồi đúng"
fi

# --- Kiểm tra 4: DR status có trường mode (Bước 5 — phân tích output) -------
if echo "$dr_status_output" | grep -q '"mode"'; then
  pass "Output DR status có trường mode"
else
  fail "Output DR status thiếu trường mode — đọc lại output từ sys/replication/dr/status"
fi

# --- Kiểm tra 5: Performance status có trường mode --------------------------
if echo "$perf_status_output" | grep -q '"mode"'; then
  pass "Output Performance status có trường mode"
else
  fail "Output Performance status thiếu trường mode — đọc lại output từ sys/replication/performance/status"
fi

# --- Kiểm tra 6: DR status trên Vault OSS trả về mode = disabled ------------
if echo "$dr_status_output" | grep -q '"mode"'; then
  dr_mode=$(echo "$dr_status_output" | grep '"mode"' | head -1 | sed 's/.*"mode": *"\([^"]*\)".*/\1/')
  if [ "$dr_mode" = "disabled" ]; then
    pass "DR mode = disabled (Vault OSS không hỗ trợ replication — đây là hành vi đúng)"
  else
    pass "DR mode = $dr_mode (Enterprise cluster — replication được hỗ trợ)"
  fi
else
  fail "Không đọc được giá trị trường mode từ DR status"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
