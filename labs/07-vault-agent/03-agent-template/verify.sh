#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Vault Agent Templating"
#
# Thứ tự kiểm tra:
#   0. Vault có thể truy cập
#   1. KV v2 engine đã được bật
#   2. Secret secret/myapp/config tồn tại và có field username
#   3. Policy agent-policy đã được tạo
#   4. File template .ctmpl tồn tại
#   5. File agent config agent.hcl tồn tại và chứa block template
#   6. File output /tmp/lab-output/config.yaml tồn tại
#   7. File output chứa giá trị "username" và "admin"
#   8. File output KHÔNG chứa cú pháp template {{

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Dang kiem tra bai thuc hanh — Vault Agent Templating"
echo

# --- Kiem tra 0: Vault dang chay -------------------------------------------
if vault status >/dev/null 2>&1; then
  pass "Vault co the truy cap tai $VAULT_ADDR"
else
  fail "Khong truy cap duoc Vault tai $VAULT_ADDR"
  echo
  echo "Vault dev server chua chay. Trong Codespace, chay:"
  echo "  nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 &"
  exit 1
fi

# --- Kiem tra 1: KV v2 engine da duoc bat ------------------------------------
# Kiem tra secrets list co chua "secret/" voi type kv
if vault secrets list -format=json 2>/dev/null | grep -q '"secret/"'; then
  pass "KV secrets engine da duoc bat tai path 'secret/'"
else
  fail "KV secrets engine chua duoc bat tai path 'secret/' — chay: vault secrets enable -path=secret kv-v2"
fi

# --- Kiem tra 2: Secret ton tai va co field username -------------------------
# Dung vault kv get de kiem tra secret va field
if vault kv get -field=username secret/myapp/config >/dev/null 2>&1; then
  USERNAME_VAL="$(vault kv get -field=username secret/myapp/config 2>/dev/null)"
  if [ "$USERNAME_VAL" = "admin" ]; then
    pass "Secret secret/myapp/config ton tai voi username='admin'"
  else
    fail "Secret secret/myapp/config ton tai nhung username='$USERNAME_VAL' (can la 'admin')"
  fi
else
  fail "Secret secret/myapp/config chua duoc tao hoac khong co field username"
fi

# --- Kiem tra 3: Policy agent-policy da duoc tao -----------------------------
if vault policy read agent-policy >/dev/null 2>&1; then
  pass "Policy 'agent-policy' da duoc tao trong Vault"
else
  fail "Policy 'agent-policy' chua duoc tao — chay: vault policy write agent-policy /tmp/lab-template/agent-policy.hcl"
fi

# --- Kiem tra 4: File template .ctmpl ton tai --------------------------------
# Tim file .ctmpl trong thu muc lam viec cua lab
CTMPL_FILE="/tmp/lab-template/app-config.ctmpl"
if [ -f "$CTMPL_FILE" ]; then
  pass "File template $CTMPL_FILE ton tai"
else
  fail "File template $CTMPL_FILE chua duoc tao"
fi

# --- Kiem tra 5: File agent.hcl ton tai va co block template -----------------
AGENT_HCL="/tmp/lab-template/agent.hcl"
if [ -f "$AGENT_HCL" ]; then
  # Kiem tra file co chua chu "template" de xac nhan block template da co
  if grep -q 'template' "$AGENT_HCL" 2>/dev/null; then
    pass "File $AGENT_HCL ton tai va chua cau hinh template"
  else
    fail "File $AGENT_HCL ton tai nhung khong tim thay block 'template'"
  fi
else
  fail "File agent config $AGENT_HCL chua duoc tao"
fi

# --- Kiem tra 6: File output ton tai -----------------------------------------
OUTPUT_FILE="/tmp/lab-output/config.yaml"
if [ -f "$OUTPUT_FILE" ]; then
  pass "File output $OUTPUT_FILE da duoc render boi Vault Agent"
else
  fail "File output $OUTPUT_FILE chua ton tai — Agent co the chua chay hoac chua render xong"
fi

# --- Kiem tra 7: File output chua gia tri dung --------------------------------
if [ -f "$OUTPUT_FILE" ]; then
  # Kiem tra co chuoi "username" trong file
  if grep -q 'username' "$OUTPUT_FILE" 2>/dev/null; then
    pass "File output chua truong 'username'"
  else
    fail "File output khong chua truong 'username' — kiem tra lai file template"
  fi

  # Kiem tra co gia tri "admin" trong file
  if grep -q 'admin' "$OUTPUT_FILE" 2>/dev/null; then
    pass "File output chua gia tri 'admin' (du lieu thuc tu Vault)"
  else
    fail "File output khong chua gia tri 'admin' — secret co the chua duoc ghi dung hoac template bi sai cu phap"
  fi
fi

# --- Kiem tra 8: File output KHONG chua cu phap template {{ ------------------
if [ -f "$OUTPUT_FILE" ]; then
  # Neu file con chua {{ thi co nghia la template chua duoc render
  if grep -q '{{' "$OUTPUT_FILE" 2>/dev/null; then
    fail "File output van chua cu phap template '{{' — Agent co the chua render xong hoac co loi"
  else
    pass "File output sach — khong con cu phap template '{{'"
  fi
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tat ca kiem tra deu dat."
  exit 0
else
  echo "$failures kiem tra chua dat."
  exit 1
fi
