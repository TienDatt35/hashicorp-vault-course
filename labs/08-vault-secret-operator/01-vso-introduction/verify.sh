#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành: Phân tích YAML manifest Vault Secrets Operator
#
# Bài lab này không yêu cầu Kubernetes cluster hay Vault thực.
# Các assertion kiểm tra sự tồn tại và nội dung của các file YAML/HCL
# mà học viên tạo ra trong quá trình làm bài.
#
# Quy ước:
#   pass "mô tả ngắn"  -> in dòng [PASS]
#   fail "mô tả ngắn"  -> in dòng [FAIL] và tăng số lỗi

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Phân tích YAML manifest Vault Secrets Operator"
echo

# --- Kiểm tra 0: Vault dev server (tùy chọn cho bài lab này) -------------------
# Bài lab không yêu cầu Vault, nhưng kiểm tra để thông báo trạng thái môi trường.
if vault status >/dev/null 2>&1; then
  pass "Vault có thể truy cập tại $VAULT_ADDR (tùy chọn cho bài lab này)"
else
  pass "Vault không chạy — bài lab này không yêu cầu Vault thực"
fi

# --- Tìm thư mục làm việc của học viên -----------------------------------------
# Script tìm kiếm file trong thư mục hiện tại và /tmp/lab-vso/
LAB_DIR=""
if [ -f "./my-vss.yaml" ]; then
  LAB_DIR="."
elif [ -f "/tmp/lab-vso/my-vss.yaml" ]; then
  LAB_DIR="/tmp/lab-vso"
fi

ANSWERS_FILE=""
if [ -f "./answers.yaml" ]; then
  ANSWERS_FILE="./answers.yaml"
elif [ -f "/tmp/lab-vso/answers.yaml" ]; then
  ANSWERS_FILE="/tmp/lab-vso/answers.yaml"
fi

POLICY_FILE=""
if [ -f "./vault-policy.hcl" ]; then
  POLICY_FILE="./vault-policy.hcl"
elif [ -f "/tmp/lab-vso/vault-policy.hcl" ]; then
  POLICY_FILE="/tmp/lab-vso/vault-policy.hcl"
fi

# --- Bước 2: Kiểm tra file my-vss.yaml -------------------------------------------

# Kiểm tra 1: File my-vss.yaml tồn tại
if [ -n "$LAB_DIR" ] && [ -f "$LAB_DIR/my-vss.yaml" ]; then
  pass "File my-vss.yaml tồn tại"
else
  fail "Không tìm thấy my-vss.yaml (thử ./my-vss.yaml hoặc /tmp/lab-vso/my-vss.yaml)"
fi

# Kiểm tra 2: File my-vss.yaml chứa kind VaultStaticSecret
if [ -n "$LAB_DIR" ] && grep -q "kind: VaultStaticSecret" "$LAB_DIR/my-vss.yaml" 2>/dev/null; then
  pass "my-vss.yaml khai báo đúng kind: VaultStaticSecret"
else
  fail "my-vss.yaml thiếu 'kind: VaultStaticSecret'"
fi

# Kiểm tra 3: File my-vss.yaml chứa đúng path myapp/database
if [ -n "$LAB_DIR" ] && grep -q "path: myapp/database" "$LAB_DIR/my-vss.yaml" 2>/dev/null; then
  pass "my-vss.yaml có path: myapp/database đúng yêu cầu"
else
  fail "my-vss.yaml thiếu 'path: myapp/database'"
fi

# Kiểm tra 4: File my-vss.yaml chứa refreshAfter: 60s
if [ -n "$LAB_DIR" ] && grep -q "refreshAfter: 60s" "$LAB_DIR/my-vss.yaml" 2>/dev/null; then
  pass "my-vss.yaml có refreshAfter: 60s đúng yêu cầu"
else
  fail "my-vss.yaml thiếu 'refreshAfter: 60s'"
fi

# Kiểm tra 5: File my-vss.yaml chứa rolloutRestartTargets
if [ -n "$LAB_DIR" ] && grep -q "rolloutRestartTargets" "$LAB_DIR/my-vss.yaml" 2>/dev/null; then
  pass "my-vss.yaml có rolloutRestartTargets để trigger restart Deployment"
else
  fail "my-vss.yaml thiếu 'rolloutRestartTargets'"
fi

# Kiểm tra 6: File my-vss.yaml khai báo K8s Secret đích tên db-secret
if [ -n "$LAB_DIR" ] && grep -q "name: db-secret" "$LAB_DIR/my-vss.yaml" 2>/dev/null; then
  pass "my-vss.yaml chỉ định destination Kubernetes Secret tên 'db-secret'"
else
  fail "my-vss.yaml thiếu 'name: db-secret' trong phần destination"
fi

# --- Bước 3: Kiểm tra file vault-policy.hcl --------------------------------------

# Kiểm tra 7: File vault-policy.hcl tồn tại
if [ -n "$POLICY_FILE" ] && [ -f "$POLICY_FILE" ]; then
  pass "File vault-policy.hcl tồn tại"
else
  fail "Không tìm thấy vault-policy.hcl (thử ./vault-policy.hcl hoặc /tmp/lab-vso/vault-policy.hcl)"
fi

# Kiểm tra 8: vault-policy.hcl chứa đúng path KV v2 (mount/data/path)
if [ -n "$POLICY_FILE" ] && grep -q "secret/data/myapp/database" "$POLICY_FILE" 2>/dev/null; then
  pass "vault-policy.hcl có đúng path KV v2: secret/data/myapp/database"
else
  fail "vault-policy.hcl thiếu path 'secret/data/myapp/database' (KV v2 cần thêm /data/ vào giữa)"
fi

# Kiểm tra 9: vault-policy.hcl khai báo capabilities
if [ -n "$POLICY_FILE" ] && grep -q "capabilities" "$POLICY_FILE" 2>/dev/null; then
  pass "vault-policy.hcl có khai báo capabilities"
else
  fail "vault-policy.hcl thiếu từ khóa 'capabilities'"
fi

# --- Bước 1 và 4: Kiểm tra file answers.yaml -------------------------------------

# Kiểm tra 10: File answers.yaml tồn tại và chứa câu trả lời cho Bước 4
if [ -n "$ANSWERS_FILE" ] && grep -q "manifest_vso" "$ANSWERS_FILE" 2>/dev/null; then
  pass "answers.yaml tồn tại và có trường manifest_vso (Bước 4)"
else
  fail "Không tìm thấy answers.yaml hoặc thiếu trường 'manifest_vso'"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
