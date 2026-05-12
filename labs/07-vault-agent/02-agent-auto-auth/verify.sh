#!/usr/bin/env bash
# verify.sh — kiểm tra bài thực hành "Vault Agent Auto-Auth và Token Sink"
#
# Kịch bản này tự thực hiện toàn bộ quy trình:
#   1. Kiểm tra Vault truy cập được
#   2. Chuẩn bị AppRole (policy, role, role_id, secret_id)
#   3. Tạo file config Agent
#   4. Chạy Agent ở background
#   5. Chờ sink file xuất hiện (tối đa 10 giây)
#   6. Kiểm tra token trong sink hợp lệ
#   7. Kiểm tra sink wrapped chứa wrapping token
#   8. Dọn dẹp tất cả tài nguyên tạm

set -uo pipefail

: "${VAULT_ADDR:=http://127.0.0.1:8200}"
: "${VAULT_TOKEN:=root}"
export VAULT_ADDR VAULT_TOKEN

failures=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; failures=$((failures + 1)); }

# Thư mục tạm để chứa các file lab
LAB_DIR="$(mktemp -d /tmp/vault-agent-lab-XXXXXX)"
ROLE_ID_FILE="$LAB_DIR/role_id"
SECRET_ID_FILE="$LAB_DIR/secret_id"
SINK_FILE="$LAB_DIR/vault-token-sink"
SINK_WRAPPED_FILE="$LAB_DIR/vault-token-sink-wrapped"
CONFIG_FILE="$LAB_DIR/agent.hcl"
PID_FILE="$LAB_DIR/vault-agent.pid"
LOG_FILE="$LAB_DIR/vault-agent.log"
AGENT_PID=""

# Hàm dọn dẹp tài nguyên khi script kết thúc
cleanup() {
  # Dừng Agent nếu đang chạy
  if [ -n "$AGENT_PID" ] && kill -0 "$AGENT_PID" 2>/dev/null; then
    kill "$AGENT_PID" 2>/dev/null || true
  fi
  # Xóa Vault resources đã tạo trong quá trình kiểm tra
  VAULT_TOKEN=root vault auth disable approle-verify 2>/dev/null || true
  VAULT_TOKEN=root vault policy delete lab-agent-verify 2>/dev/null || true
  VAULT_TOKEN=root vault kv delete secret/lab-verify-test 2>/dev/null || true
  # Xóa thư mục tạm
  rm -rf "$LAB_DIR"
}
trap cleanup EXIT

echo "Dang kiem tra bai thuc hanh — Vault Agent Auto-Auth va Token Sink"
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

# --- Kiem tra 1: Chuan bi AppRole (tuong ung buoc 1 trong README) ----------
# Bat AppRole tren mount path rieng de tranh xung dot voi AppRole hoc vien da cau hinh
if VAULT_TOKEN=root vault auth enable -path=approle-verify approle >/dev/null 2>&1; then
  pass "Da bat AppRole auth method tai auth/approle-verify"
else
  # Co the da ton tai tu lan chay truoc — thu disable roi enable lai
  VAULT_TOKEN=root vault auth disable approle-verify >/dev/null 2>&1 || true
  if VAULT_TOKEN=root vault auth enable -path=approle-verify approle >/dev/null 2>&1; then
    pass "Da bat AppRole auth method tai auth/approle-verify"
  else
    fail "Khong the bat AppRole auth method"
  fi
fi

# Tao policy cho role
if VAULT_TOKEN=root vault policy write lab-agent-verify - >/dev/null 2>&1 <<'POLICY'
path "secret/data/lab-verify-test" {
  capabilities = ["read"]
}
POLICY
then
  pass "Da tao policy lab-agent-verify"
else
  fail "Khong the tao policy lab-agent-verify"
fi

# Tao role va lay role_id
if VAULT_TOKEN=root vault write auth/approle-verify/role/lab-agent-verify \
    token_policies="lab-agent-verify" \
    token_ttl=30m \
    token_max_ttl=1h >/dev/null 2>&1; then
  pass "Da tao AppRole role lab-agent-verify"
else
  fail "Khong the tao AppRole role"
fi

if VAULT_TOKEN=root vault read -field=role_id auth/approle-verify/role/lab-agent-verify/role-id > "$ROLE_ID_FILE" 2>/dev/null; then
  pass "Da ghi role_id vao file"
else
  fail "Khong the lay role_id"
fi

if VAULT_TOKEN=root vault write -field=secret_id -f auth/approle-verify/role/lab-agent-verify/secret-id > "$SECRET_ID_FILE" 2>/dev/null; then
  pass "Da ghi secret_id vao file"
else
  fail "Khong the lay secret_id"
fi

# --- Kiem tra 2: Tao file config Agent (tuong ung buoc 2 trong README) ----
cat > "$CONFIG_FILE" <<EOF
pid_file = "$PID_FILE"

vault {
  address = "$VAULT_ADDR"
}

auto_auth {
  method {
    type       = "approle"
    mount_path = "auth/approle-verify"
    config = {
      role_id_file_path                   = "$ROLE_ID_FILE"
      secret_id_file_path                 = "$SECRET_ID_FILE"
      remove_secret_id_file_after_reading = false
    }
  }

  sink {
    type = "file"
    config = {
      path = "$SINK_FILE"
      mode = 0640
    }
  }

  sink {
    type     = "file"
    wrap_ttl = "5m"
    config = {
      path = "$SINK_WRAPPED_FILE"
      mode = 0640
    }
  }
}
EOF

if [ -f "$CONFIG_FILE" ]; then
  pass "Da tao file config Agent (agent.hcl)"
else
  fail "Khong the tao file config Agent"
fi

# --- Kiem tra 3: Chay Agent o background (tuong ung buoc 3 trong README) --
vault agent -config="$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
AGENT_PID=$!

# Kiem tra Agent da khoi dong
if kill -0 "$AGENT_PID" 2>/dev/null; then
  pass "Vault Agent da khoi dong (PID: $AGENT_PID)"
else
  fail "Vault Agent khong khoi dong duoc"
  echo "  Log Agent:"
  cat "$LOG_FILE" 2>/dev/null | head -20
fi

# --- Kiem tra 4: Doi sink file xuat hien (tuong ung buoc 4 trong README) --
SINK_TIMEOUT=10
SINK_WAITED=0
while [ ! -f "$SINK_FILE" ] && [ "$SINK_WAITED" -lt "$SINK_TIMEOUT" ]; do
  sleep 1
  SINK_WAITED=$((SINK_WAITED + 1))
done

if [ -f "$SINK_FILE" ]; then
  pass "Sink file xuat hien sau ${SINK_WAITED}s ($SINK_FILE)"
else
  fail "Sink file khong xuat hien sau ${SINK_TIMEOUT}s — Agent co the bi loi"
  echo "  Log Agent:"
  cat "$LOG_FILE" 2>/dev/null | tail -20
fi

# --- Kiem tra 5: Token trong sink hop le (tuong ung buoc 4 trong README) --
if [ -f "$SINK_FILE" ]; then
  SINK_TOKEN="$(cat "$SINK_FILE")"
  if [ -n "$SINK_TOKEN" ]; then
    if VAULT_TOKEN="$SINK_TOKEN" vault token lookup >/dev/null 2>&1; then
      pass "Token trong sink hop le — vault token lookup thanh cong"
    else
      fail "Token trong sink khong hop le hoac het han"
    fi
  else
    fail "File sink ton tai nhung trong — token chua duoc ghi"
  fi
fi

# --- Kiem tra 6: Dung token tu sink de doc secret (tuong ung buoc 5) ------
# Tao secret truoc bang root token
if VAULT_TOKEN=root vault kv put secret/lab-verify-test message="hello from vault" >/dev/null 2>&1; then
  pass "Da tao secret tai secret/lab-verify-test"
else
  fail "Khong the tao secret tai secret/lab-verify-test"
fi

if [ -f "$SINK_FILE" ]; then
  SINK_TOKEN="$(cat "$SINK_FILE")"
  if VAULT_TOKEN="$SINK_TOKEN" vault kv get -field=message secret/lab-verify-test >/dev/null 2>&1; then
    pass "Token tu sink co the doc secret tai secret/data/lab-verify-test"
  else
    fail "Token tu sink khong doc duoc secret — kiem tra policy cua role"
  fi
fi

# --- Kiem tra 7: Doi sink wrapped xuat hien (tuong ung buoc 6) -----------
WRAPPED_WAITED=0
while [ ! -f "$SINK_WRAPPED_FILE" ] && [ "$WRAPPED_WAITED" -lt 5 ]; do
  sleep 1
  WRAPPED_WAITED=$((WRAPPED_WAITED + 1))
done

if [ -f "$SINK_WRAPPED_FILE" ]; then
  pass "Sink wrapped file xuat hien ($SINK_WRAPPED_FILE)"
else
  fail "Sink wrapped file khong xuat hien — kiem tra cau hinh wrap_ttl"
fi

# --- Kiem tra 8: Wrapping token khong dung nhu token thuong ---------------
if [ -f "$SINK_WRAPPED_FILE" ]; then
  WRAPPED_CONTENT="$(cat "$SINK_WRAPPED_FILE")"
  if [ -n "$WRAPPED_CONTENT" ]; then
    # Agent ghi JSON response vao wrapped sink (co truong "token", "ttl", v.v.)
    # Can extract truong "token" truoc khi unwrap
    WRAPPED_TOKEN=$(echo "$WRAPPED_CONTENT" | jq -r '.token // empty' 2>/dev/null || echo "")
    if [ -z "$WRAPPED_TOKEN" ]; then
      # Fallback: thu dung nhu raw token neu khong phai JSON
      WRAPPED_TOKEN="$WRAPPED_CONTENT"
    fi

    # Wrapping token KHONG the dung voi vault token lookup thong thuong
    if VAULT_TOKEN="$WRAPPED_TOKEN" vault token lookup >/dev/null 2>&1; then
      fail "Token trong sink wrapped tra loi nhu token thuong — co the khong phai wrapping token"
    else
      pass "Token trong sink wrapped khong lookup duoc truc tiep — xac nhan la wrapping token"
    fi
    # Kiem tra co the unwrap duoc
    if VAULT_TOKEN=root vault unwrap "$WRAPPED_TOKEN" >/dev/null 2>&1; then
      pass "Co the unwrap token trong sink wrapped — wrapping token hop le"
    else
      fail "Khong the unwrap token trong sink wrapped — wrapping token co the da het han"
    fi
  else
    fail "File sink wrapped ton tai nhung trong"
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
