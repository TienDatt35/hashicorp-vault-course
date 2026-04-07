#!/usr/bin/env bash
# Apply the reference solution. Each lab fills this in with the canonical
# vault commands or HCL needed to make verify.sh pass. CI runs:
#   make solution
# which executes this script then re-runs verify.sh, catching lab rot when
# Vault releases change behavior.
set -euo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

echo "Đang áp dụng đáp án mẫu — TEMPLATE (chưa có hành động)"
