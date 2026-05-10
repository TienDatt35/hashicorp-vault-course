#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Thực hành nhận diện Vault Agent và Proxy
#
# Script này kiểm tra:
#   0. Vault dev server có thể truy cập
#   1. Binary vault có sẵn và lệnh "vault agent --help" chạy được
#   2. Binary vault có sẵn và lệnh "vault proxy --help" chạy được
#   3. File /tmp/lab-agent.hcl tồn tại
#   4. File /tmp/lab-agent.hcl có stanza auto_auth
#   5. File /tmp/lab-agent.hcl có stanza cache
#   6. File /tmp/lab-agent.hcl có stanza template
#   7. File /tmp/lab-proxy.hcl tồn tại
#   8. File /tmp/lab-proxy.hcl có stanza auto_auth
#   9. File /tmp/lab-proxy.hcl có stanza api_proxy
#  10. File /tmp/lab-proxy.hcl có stanza listener

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Nhận diện Vault Agent và Proxy"
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

# --- Kiểm tra 1: Lệnh "vault agent --help" chạy được -----------------------
if vault agent --help >/dev/null 2>&1; then
  pass "Lệnh 'vault agent --help' chạy thành công"
else
  fail "Lệnh 'vault agent --help' thất bại — kiểm tra lại binary vault"
fi

# --- Kiểm tra 2: Lệnh "vault proxy --help" chạy được -----------------------
if vault proxy --help >/dev/null 2>&1; then
  pass "Lệnh 'vault proxy --help' chạy thành công"
else
  fail "Lệnh 'vault proxy --help' thất bại — kiểm tra lại phiên bản vault (cần 1.13+)"
fi

# --- Kiểm tra 3: File cấu hình Agent tồn tại --------------------------------
if [ -f "/tmp/lab-agent.hcl" ]; then
  pass "File /tmp/lab-agent.hcl tồn tại"
else
  fail "Không tìm thấy /tmp/lab-agent.hcl — hãy tạo file này theo Bước 2"
fi

# --- Kiểm tra 4: File Agent có stanza auto_auth -----------------------------
if [ -f "/tmp/lab-agent.hcl" ] && grep -q "auto_auth" /tmp/lab-agent.hcl; then
  pass "File /tmp/lab-agent.hcl chứa stanza 'auto_auth'"
else
  fail "Không tìm thấy 'auto_auth' trong /tmp/lab-agent.hcl — Agent cần stanza này để tự xác thực"
fi

# --- Kiểm tra 5: File Agent có stanza cache ---------------------------------
if [ -f "/tmp/lab-agent.hcl" ] && grep -q "^cache" /tmp/lab-agent.hcl; then
  pass "File /tmp/lab-agent.hcl chứa stanza 'cache'"
else
  fail "Không tìm thấy stanza 'cache' ở đầu dòng trong /tmp/lab-agent.hcl"
fi

# --- Kiểm tra 6: File Agent có stanza template ------------------------------
if [ -f "/tmp/lab-agent.hcl" ] && grep -q "^template" /tmp/lab-agent.hcl; then
  pass "File /tmp/lab-agent.hcl chứa stanza 'template'"
else
  fail "Không tìm thấy stanza 'template' ở đầu dòng trong /tmp/lab-agent.hcl — đây là tính năng templating của Agent"
fi

# --- Kiểm tra 7: File cấu hình Proxy tồn tại --------------------------------
if [ -f "/tmp/lab-proxy.hcl" ]; then
  pass "File /tmp/lab-proxy.hcl tồn tại"
else
  fail "Không tìm thấy /tmp/lab-proxy.hcl — hãy tạo file này theo Bước 3"
fi

# --- Kiểm tra 8: File Proxy có stanza auto_auth -----------------------------
if [ -f "/tmp/lab-proxy.hcl" ] && grep -q "auto_auth" /tmp/lab-proxy.hcl; then
  pass "File /tmp/lab-proxy.hcl chứa stanza 'auto_auth'"
else
  fail "Không tìm thấy 'auto_auth' trong /tmp/lab-proxy.hcl — Proxy cũng cần stanza này"
fi

# --- Kiểm tra 9: File Proxy có stanza api_proxy -----------------------------
if [ -f "/tmp/lab-proxy.hcl" ] && grep -q "api_proxy" /tmp/lab-proxy.hcl; then
  pass "File /tmp/lab-proxy.hcl chứa stanza 'api_proxy'"
else
  fail "Không tìm thấy 'api_proxy' trong /tmp/lab-proxy.hcl — đây là stanza bắt buộc của Vault Proxy"
fi

# --- Kiểm tra 10: File Proxy có stanza listener -----------------------------
if [ -f "/tmp/lab-proxy.hcl" ] && grep -q "listener" /tmp/lab-proxy.hcl; then
  pass "File /tmp/lab-proxy.hcl chứa stanza 'listener'"
else
  fail "Không tìm thấy 'listener' trong /tmp/lab-proxy.hcl — đây là stanza bắt buộc của Vault Proxy"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
