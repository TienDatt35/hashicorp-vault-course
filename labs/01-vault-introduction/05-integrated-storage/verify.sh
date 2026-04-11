#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Thực hành Raft: list-peers và snapshot"
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

# Lấy đường dẫn thư mục chứa verify.sh (dùng cho kiểm tra file HCL)
LAB_DIR="$(dirname "$0")"

echo "Đang kiểm tra bài thực hành — Thực hành Raft: list-peers và snapshot"
echo

# --- Kiểm tra 1: Vault có thể truy cập ---------------------------------------
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR"
else
  fail "Không truy cập được Vault tại $VAULT_ADDR"
  echo
  echo "Vault dev server chưa chạy. Trong Codespace, chạy:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiểm tra 2: Raft API hoạt động (list-peers) -----------------------------
# Kiểm tra bước 2 trong README: vault operator raft list-peers
if vault operator raft list-peers >/dev/null 2>&1; then
  pass "vault operator raft list-peers chạy thành công"
else
  fail "vault operator raft list-peers thất bại — Raft API không hoạt động"
fi

# --- Kiểm tra 3: Tạo snapshot thành công và file có kích thước > 0 -----------
# Kiểm tra bước 3 trong README: vault operator raft snapshot save
SNAP_FILE="/tmp/vault-verify-test-$$.snap"
if vault operator raft snapshot save "$SNAP_FILE" >/dev/null 2>&1; then
  if [ -s "$SNAP_FILE" ]; then
    pass "Snapshot tạo thành công tại $SNAP_FILE (kích thước > 0)"
  else
    fail "Snapshot được tạo nhưng file rỗng — kích thước = 0"
    rm -f "$SNAP_FILE"
  fi
else
  fail "vault operator raft snapshot save thất bại — không tạo được snapshot"
  rm -f "$SNAP_FILE"
fi

# --- Kiểm tra 4: Restore snapshot thành công ---------------------------------
# Kiểm tra bước 5 trong README: vault operator raft snapshot restore
# Dùng lại snapshot từ kiểm tra 3 (nếu tồn tại) trước khi cleanup
if [ -s "$SNAP_FILE" ]; then
  # Thêm -force để tránh prompt xác nhận trong môi trường dev server
  if vault operator raft snapshot restore -force "$SNAP_FILE" >/dev/null 2>&1; then
    pass "vault operator raft snapshot restore chạy thành công"
  else
    fail "vault operator raft snapshot restore thất bại"
  fi
  # Dọn dẹp file tạm sau khi đã restore
  rm -f "$SNAP_FILE"
else
  fail "Bỏ qua kiểm tra restore — snapshot ở kiểm tra 3 không tồn tại"
fi

# --- Kiểm tra 5: File raft-cluster.hcl tồn tại trong thư mục lab -------------
# Kiểm tra bước 4 trong README: đọc file config mẫu
if [ -f "$LAB_DIR/raft-cluster.hcl" ]; then
  pass "File raft-cluster.hcl tồn tại trong thư mục lab"
else
  fail "File raft-cluster.hcl không tìm thấy tại $LAB_DIR/raft-cluster.hcl"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
