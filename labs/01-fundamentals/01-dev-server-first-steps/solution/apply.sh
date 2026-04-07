#!/usr/bin/env bash
# Reference solution for Lab 1.1.
set -euo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

echo "Đang ghi secret/hello message=world …"
vault kv put secret/hello message=world
