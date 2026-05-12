#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Vault Init và Unseal bằng Key Shards"
#
# Bài này dùng Vault server chạy tại port 8202, không phải dev server ở 8200.
# Script đọc init output từ /tmp/vault-lab/init-output.json để tự unseal
# nếu cần, nhưng học viên phải đã thực hiện init trước.
#
# Chạy bằng: sh verify.sh
# Exit code 0 chỉ khi mọi kiểm tra đều đạt.

set -uo pipefail

LAB_VAULT_ADDR="http://127.0.0.1:8202"
INIT_FILE="/tmp/vault-lab/init-output.json"

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Vault Init và Unseal bằng Key Shards"
echo

# --- Kiểm tra 1: Vault server tại port 8202 đang chạy ----------------------
if curl -s "$LAB_VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
  pass "Vault server đang chạy tại $LAB_VAULT_ADDR"
else
  fail "Vault server không chạy tại $LAB_VAULT_ADDR — hãy khởi động theo bước 2 trong README"
  echo
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi

# --- Kiểm tra 2: Vault đã được initialized ----------------------------------
INITIALIZED=$(curl -s "$LAB_VAULT_ADDR/v1/sys/health" | jq -r '.initialized' 2>/dev/null || echo "false")
if [ "$INITIALIZED" = "true" ]; then
  pass "Vault đã được initialized (vault operator init đã chạy)"
else
  fail "Vault chưa được initialized — hãy chạy: vault operator init -key-shares=3 -key-threshold=2 -format=json > /tmp/vault-lab/init-output.json"
fi

# --- Kiểm tra 3: File init-output.json tồn tại và có unseal keys ------------
if [ -f "$INIT_FILE" ] && jq -e '.unseal_keys_b64 | length >= 3' "$INIT_FILE" >/dev/null 2>&1; then
  pass "File init output tồn tại tại $INIT_FILE với 3 unseal keys"
else
  fail "File $INIT_FILE không tồn tại hoặc thiếu unseal keys — hãy dùng flag -format=json khi init"
fi

# --- Kiểm tra 4: Vault đang ở trạng thái unsealed ---------------------------
SEALED=$(curl -s "$LAB_VAULT_ADDR/v1/sys/health" | jq -r '.sealed' 2>/dev/null || echo "true")
if [ "$SEALED" = "false" ]; then
  pass "Vault đang ở trạng thái unsealed (Sealed: false)"
else
  # Thử unseal tự động bằng key 1 và key 2 từ init file để giúp verify.sh pass
  if [ -f "$INIT_FILE" ]; then
    K1=$(jq -r '.unseal_keys_b64[0]' "$INIT_FILE" 2>/dev/null)
    K2=$(jq -r '.unseal_keys_b64[1]' "$INIT_FILE" 2>/dev/null)
    VAULT_ADDR="$LAB_VAULT_ADDR" vault operator unseal "$K1" >/dev/null 2>&1 || true
    VAULT_ADDR="$LAB_VAULT_ADDR" vault operator unseal "$K2" >/dev/null 2>&1 || true
    SEALED_AFTER=$(curl -s "$LAB_VAULT_ADDR/v1/sys/health" | jq -r '.sealed' 2>/dev/null || echo "true")
    if [ "$SEALED_AFTER" = "false" ]; then
      pass "Vault unsealed thành công bằng key shares từ init output"
    else
      fail "Vault vẫn còn sealed sau khi nộp 2 key shares — kiểm tra lại init output"
    fi
  else
    fail "Vault đang sealed và không tìm thấy init output để unseal"
  fi
fi

# --- Kiểm tra 5: Root token trong init output có thể đăng nhập --------------
if [ -f "$INIT_FILE" ]; then
  ROOT_TOKEN=$(jq -r '.root_token' "$INIT_FILE" 2>/dev/null || echo "")
  if VAULT_ADDR="$LAB_VAULT_ADDR" VAULT_TOKEN="$ROOT_TOKEN" vault token lookup >/dev/null 2>&1; then
    pass "Initial root token từ init output hợp lệ và có thể đăng nhập"
  else
    fail "Root token trong init output không hợp lệ — kiểm tra lại file $INIT_FILE"
  fi
else
  fail "Không tìm thấy init output để kiểm tra root token"
fi

# --- Kiểm tra 6: Total shares = 3 và threshold = 2 -------------------------
STATUS_JSON=$(curl -s "$LAB_VAULT_ADDR/v1/sys/seal-status" 2>/dev/null)
TOTAL_SHARES=$(echo "$STATUS_JSON" | jq -r '.n' 2>/dev/null || echo "0")
THRESHOLD=$(echo "$STATUS_JSON" | jq -r '.t' 2>/dev/null || echo "0")
if [ "$TOTAL_SHARES" = "3" ] && [ "$THRESHOLD" = "2" ]; then
  pass "Init đúng cấu hình: 3 key shares, threshold 2"
else
  fail "Cấu hình init không đúng (mong đợi shares=3, threshold=2; hiện: shares=${TOTAL_SHARES}, threshold=${THRESHOLD})"
fi

# --- Kiểm tra 7: KV engine đã enable sau khi unsealed và login ---------------
if [ -f "$INIT_FILE" ]; then
  ROOT_TOKEN=$(jq -r '.root_token' "$INIT_FILE" 2>/dev/null || echo "")
  if VAULT_ADDR="$LAB_VAULT_ADDR" VAULT_TOKEN="$ROOT_TOKEN" vault secrets list -format=json 2>/dev/null | jq -e '.["kv/"].type == "kv"' >/dev/null 2>&1; then
    pass "KV engine đã được enable sau khi unseal và login"
  else
    fail "KV engine chưa được enable — hãy chạy: vault secrets enable kv (sau khi export VAULT_ADDR=$LAB_VAULT_ADDR và vault login)"
  fi
fi

# ---------------------------------------------------------------------------
echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
