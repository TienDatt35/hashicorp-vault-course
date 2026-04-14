#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Cú pháp Path và Capabilities trong Vault Policy"
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi
#
# Chạy: bash verify.sh

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Cú pháp Path và Capabilities trong Vault Policy"
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

# --- Kiểm tra 1: Policy "jenkins-dev" tồn tại (Bước 1) ---------------------
if vault policy read jenkins-dev >/dev/null 2>&1; then
  pass "Policy 'jenkins-dev' tồn tại"
else
  fail "Policy 'jenkins-dev' chưa được tạo — chạy: vault policy write jenkins-dev jenkins-dev.hcl"
fi

# --- Kiểm tra 2: Policy "aws-consumer" tồn tại (Bước 2) --------------------
if vault policy read aws-consumer >/dev/null 2>&1; then
  pass "Policy 'aws-consumer' tồn tại"
else
  fail "Policy 'aws-consumer' chưa được tạo — chạy: vault policy write aws-consumer aws-consumer.hcl"
fi

# --- Kiểm tra 3: Policy "policy-admin" tồn tại (Bước 3) --------------------
if vault policy read policy-admin >/dev/null 2>&1; then
  pass "Policy 'policy-admin' tồn tại"
else
  fail "Policy 'policy-admin' chưa được tạo — chạy: vault policy write policy-admin policy-admin.hcl"
fi

# --- Kiểm tra 4: "jenkins-dev" chứa path KV v2 đúng (Bước 1) ---------------
JENKINS_DEV_CONTENT=$(vault policy read jenkins-dev 2>/dev/null || echo "")
if echo "$JENKINS_DEV_CONTENT" | grep -q 'secret/data/apps/jenkins'; then
  pass "Policy 'jenkins-dev' chứa path KV v2 đúng: secret/data/apps/jenkins"
else
  fail "Policy 'jenkins-dev' không có path 'secret/data/apps/jenkins' — KV v2 cần tiền tố data/"
fi

# --- Kiểm tra 5: "jenkins-dev" chứa path metadata để list (Bước 1) ---------
if echo "$JENKINS_DEV_CONTENT" | grep -q 'secret/metadata/apps/jenkins'; then
  pass "Policy 'jenkins-dev' chứa path metadata: secret/metadata/apps/jenkins"
else
  fail "Policy 'jenkins-dev' không có path 'secret/metadata/apps/jenkins' — cần rule riêng để list KV v2"
fi

# --- Kiểm tra 6: "aws-consumer" chứa capability "read" (Bước 2) ------------
AWS_CONSUMER_CONTENT=$(vault policy read aws-consumer 2>/dev/null || echo "")
if echo "$AWS_CONSUMER_CONTENT" | grep -q '"read"'; then
  pass "Policy 'aws-consumer' chứa capability 'read'"
else
  fail "Policy 'aws-consumer' không có capability 'read' — dùng read để lấy dynamic credentials"
fi

# --- Kiểm tra 7: "aws-consumer" trỏ đúng path AWS creds (Bước 2) -----------
if echo "$AWS_CONSUMER_CONTENT" | grep -q 'aws/creds/webapp-role'; then
  pass "Policy 'aws-consumer' chứa path đúng: aws/creds/webapp-role"
else
  fail "Policy 'aws-consumer' không có path 'aws/creds/webapp-role'"
fi

# --- Kiểm tra 8: "policy-admin" chứa path sys/policies/acl (Bước 3) --------
POLICY_ADMIN_CONTENT=$(vault policy read policy-admin 2>/dev/null || echo "")
if echo "$POLICY_ADMIN_CONTENT" | grep -q 'sys/policies/acl'; then
  pass "Policy 'policy-admin' chứa path: sys/policies/acl"
else
  fail "Policy 'policy-admin' không có path 'sys/policies/acl' — kiểm tra nội dung file policy-admin.hcl"
fi

# --- Kiểm tra 9: Secret jenkins/config tồn tại trong KV v2 (Bước 4) --------
if vault kv get secret/apps/jenkins/config >/dev/null 2>&1; then
  pass "Secret 'secret/apps/jenkins/config' tồn tại trong KV v2"
else
  fail "Secret 'secret/apps/jenkins/config' chưa được tạo — chạy: vault kv put secret/apps/jenkins/config url=http://jenkins:8080"
fi

# --- Kiểm tra 10: Ba policies có trong kết quả vault policy list (Bước 5) --
POLICY_LIST=$(vault policy list 2>/dev/null || echo "")

if echo "$POLICY_LIST" | grep -q 'jenkins-dev'; then
  pass "'vault policy list' hiển thị 'jenkins-dev'"
else
  fail "'vault policy list' không có 'jenkins-dev'"
fi

if echo "$POLICY_LIST" | grep -q 'aws-consumer'; then
  pass "'vault policy list' hiển thị 'aws-consumer'"
else
  fail "'vault policy list' không có 'aws-consumer'"
fi

if echo "$POLICY_LIST" | grep -q 'policy-admin'; then
  pass "'vault policy list' hiển thị 'policy-admin'"
else
  fail "'vault policy list' không có 'policy-admin'"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
