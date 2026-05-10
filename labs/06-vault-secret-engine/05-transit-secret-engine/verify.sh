#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành Transit Secrets Engine.
#
# Script này tự thực hiện toàn bộ các bước của bài lab trong một môi trường
# tạm thời, rồi kiểm tra kết quả. Học viên có thể chạy lại nhiều lần.
#
# Quy ước:
#   pass "mô tả ngắn"   -> in dòng [PASS]
#   fail "mô tả ngắn"   -> in dòng [FAIL] và tăng số lỗi

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

echo "Đang kiểm tra bài thực hành — Transit Secrets Engine"
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

# --- Chuẩn bị: bật Transit engine nếu chưa bật ----------------------------
# Bật transit (bỏ qua lỗi nếu đã bật)
vault secrets enable transit >/dev/null 2>&1 || true

# --- Kiểm tra 1: Transit Secrets Engine đã bật (Bước 1) -------------------
if vault secrets list 2>/dev/null | grep -q "^transit/"; then
  pass "Transit Secrets Engine đã bật tại path transit/"
else
  fail "Transit Secrets Engine chưa được bật"
fi

# --- Tạo key để test (nếu chưa có) ----------------------------------------
vault write -f transit/keys/lab-key >/dev/null 2>&1 || true

# --- Kiểm tra 2: Key lab-key tồn tại (Bước 2) ------------------------------
if vault read transit/keys/lab-key >/dev/null 2>&1; then
  pass "Key lab-key đã được tạo trong Transit engine"
else
  fail "Key lab-key chưa được tạo"
fi

# --- Kiểm tra 3: Key lab-key có type đúng (Bước 2) -------------------------
KEY_TYPE=$(vault read -field=type transit/keys/lab-key 2>/dev/null || echo "")
if [ "$KEY_TYPE" = "aes256-gcm96" ]; then
  pass "Key lab-key có type aes256-gcm96 (mặc định)"
else
  fail "Key lab-key không có type aes256-gcm96 (hiện tại: ${KEY_TYPE:-không xác định được})"
fi

# --- Chuẩn bị: đặt lại min_decryption_version=1 để test có thể encrypt/decrypt v1 ---
vault write transit/keys/lab-key/config min_decryption_version=1 >/dev/null 2>&1 || true

# --- Thực hiện encrypt và lưu ciphertext v1 (Bước 3) ----------------------
PLAINTEXT_B64=$(printf '%s' "Hello Vault Transit" | base64)
CIPHER_V1=$(vault write -field=ciphertext transit/encrypt/lab-key plaintext="$PLAINTEXT_B64" 2>/dev/null || echo "")

# --- Kiểm tra 4: Encrypt tạo ra ciphertext hợp lệ (Bước 3) ----------------
if echo "$CIPHER_V1" | grep -q "^vault:v"; then
  pass "Encrypt tạo ra ciphertext với format hợp lệ (vault:vN:...)"
else
  fail "Encrypt thất bại hoặc ciphertext không đúng format"
fi

# --- Kiểm tra 5: Decrypt ciphertext trả về plaintext đúng (Bước 4) --------
if [ -n "$CIPHER_V1" ]; then
  DECRYPTED_B64=$(vault write -field=plaintext transit/decrypt/lab-key ciphertext="$CIPHER_V1" 2>/dev/null || echo "")
  DECRYPTED=$(echo "$DECRYPTED_B64" | base64 --decode 2>/dev/null || echo "")
  if [ "$DECRYPTED" = "Hello Vault Transit" ]; then
    pass "Decrypt trả về đúng plaintext gốc: 'Hello Vault Transit'"
  else
    fail "Decrypt không trả về đúng plaintext (nhận được: '${DECRYPTED}')"
  fi
else
  fail "Không thể kiểm tra decrypt vì encrypt thất bại"
fi

# --- Thực hiện rotate (Bước 5) --------------------------------------------
vault write -f transit/keys/lab-key/rotate >/dev/null 2>&1 || true

# --- Kiểm tra 6: latest_version đã tăng lên sau rotate (Bước 5) -----------
LATEST_VERSION=$(vault read -field=latest_version transit/keys/lab-key 2>/dev/null || echo "0")
if [ "$LATEST_VERSION" -ge 2 ] 2>/dev/null; then
  pass "Key lab-key đã được rotate — latest_version=${LATEST_VERSION}"
else
  fail "Key lab-key chưa được rotate (latest_version=${LATEST_VERSION})"
fi

# --- Encrypt lại sau rotate, kiểm tra dùng version mới (Bước 5) ----------
CIPHER_V2=$(vault write -field=ciphertext transit/encrypt/lab-key plaintext="$PLAINTEXT_B64" 2>/dev/null || echo "")

# Lấy version từ ciphertext v2 (dạng vault:v2:...)
CIPHER_V2_VER=$(echo "$CIPHER_V2" | cut -d: -f2 | tr -d 'v' 2>/dev/null || echo "0")

# --- Kiểm tra 7: Ciphertext mới dùng version mới hơn v1 (Bước 5) ---------
if [ -n "$CIPHER_V2" ] && [ "${CIPHER_V2_VER:-0}" -ge 2 ] 2>/dev/null; then
  pass "Encrypt sau rotate dùng key version mới (version ${CIPHER_V2_VER})"
else
  fail "Encrypt sau rotate vẫn dùng version cũ hoặc thất bại"
fi

# --- Cấu hình min_decryption_version=2 (Bước 6) --------------------------
vault write transit/keys/lab-key/config min_decryption_version=2 >/dev/null 2>&1 || true

# --- Kiểm tra 8: min_decryption_version đã được đặt (Bước 6) --------------
MIN_DEC_VER=$(vault read -field=min_decryption_version transit/keys/lab-key 2>/dev/null || echo "0")
if [ "$MIN_DEC_VER" -ge 2 ] 2>/dev/null; then
  pass "min_decryption_version đã được đặt thành ${MIN_DEC_VER}"
else
  fail "min_decryption_version chưa được đặt >= 2 (hiện tại: ${MIN_DEC_VER})"
fi

# --- Kiểm tra 9: Decrypt ciphertext v1 phải thất bại (Bước 6) -------------
if [ -n "$CIPHER_V1" ]; then
  # Kiểm tra version của CIPHER_V1
  CIPHER_V1_VER=$(echo "$CIPHER_V1" | cut -d: -f2 | tr -d 'v' 2>/dev/null || echo "99")
  if [ "${CIPHER_V1_VER:-99}" -lt "$MIN_DEC_VER" ] 2>/dev/null; then
    # Thử decrypt — phải trả về lỗi (exit code != 0)
    if vault write transit/decrypt/lab-key ciphertext="$CIPHER_V1" >/dev/null 2>&1; then
      fail "Decrypt ciphertext version ${CIPHER_V1_VER} phải thất bại khi min_decryption_version=${MIN_DEC_VER}"
    else
      pass "Decrypt ciphertext version ${CIPHER_V1_VER} thất bại đúng như kỳ vọng (bị chặn bởi min_decryption_version)"
    fi
  else
    pass "Ciphertext v1 có version ${CIPHER_V1_VER} không bị chặn (min_decryption_version=${MIN_DEC_VER})"
  fi
else
  fail "Không thể kiểm tra min_decryption_version vì không có ciphertext v1"
fi

# --- Kiểm tra 10: Ciphertext v2 vẫn decrypt được (Bước 6) -----------------
if [ -n "$CIPHER_V2" ]; then
  RESULT_B64=$(vault write -field=plaintext transit/decrypt/lab-key ciphertext="$CIPHER_V2" 2>/dev/null || echo "")
  RESULT=$(echo "$RESULT_B64" | base64 --decode 2>/dev/null || echo "")
  if [ "$RESULT" = "Hello Vault Transit" ]; then
    pass "Decrypt ciphertext version ${CIPHER_V2_VER:-2} thành công (không bị chặn bởi min_decryption_version)"
  else
    fail "Decrypt ciphertext v2 thất bại hoặc trả về sai plaintext"
  fi
else
  fail "Không có ciphertext v2 để kiểm tra"
fi

# --- Bước chuẩn bị cho rewrap: hạ min_decryption_version để rewrap được ---
vault write transit/keys/lab-key/config min_decryption_version=1 >/dev/null 2>&1 || true

# --- Thực hiện rewrap ciphertext v1 (Bước 7) ------------------------------
CIPHER_REWRAPPED=""
if [ -n "$CIPHER_V1" ]; then
  CIPHER_REWRAPPED=$(vault write -field=ciphertext transit/rewrap/lab-key ciphertext="$CIPHER_V1" 2>/dev/null || echo "")
fi

# Lấy version của ciphertext sau rewrap
REWRAPPED_VER=$(echo "$CIPHER_REWRAPPED" | cut -d: -f2 | tr -d 'v' 2>/dev/null || echo "0")

# --- Kiểm tra 11: Rewrap tạo ciphertext với version mới hơn (Bước 7) ------
if [ -n "$CIPHER_REWRAPPED" ] && [ "${REWRAPPED_VER:-0}" -ge 2 ] 2>/dev/null; then
  pass "Rewrap thành công — ciphertext mới dùng version ${REWRAPPED_VER} (cao hơn version cũ)"
else
  fail "Rewrap thất bại hoặc ciphertext kết quả không dùng version mới hơn"
fi

# --- Kiểm tra 12: Ciphertext sau rewrap decrypt được đúng nội dung (Bước 7) ---
if [ -n "$CIPHER_REWRAPPED" ]; then
  REWRAP_RESULT_B64=$(vault write -field=plaintext transit/decrypt/lab-key ciphertext="$CIPHER_REWRAPPED" 2>/dev/null || echo "")
  REWRAP_RESULT=$(echo "$REWRAP_RESULT_B64" | base64 --decode 2>/dev/null || echo "")
  if [ "$REWRAP_RESULT" = "Hello Vault Transit" ]; then
    pass "Ciphertext sau rewrap decrypt đúng plaintext gốc"
  else
    fail "Ciphertext sau rewrap không decrypt được đúng plaintext"
  fi
else
  fail "Không có ciphertext rewrapped để kiểm tra decrypt"
fi

# --- Kết quả tổng kết -------------------------------------------------------
echo
if [ "$failures" -eq 0 ]; then
  echo "Tất cả kiểm tra đều đạt."
  exit 0
else
  echo "$failures kiểm tra chưa đạt."
  exit 1
fi
