#!/usr/bin/env bash
set -euo pipefail

# Install Vault by downloading the official binary zip directly.
# We avoid the apt package because its postinstall sets the IPC_LOCK file
# capability on /usr/bin/vault, which causes "Operation not permitted" when
# executing the binary inside an unprivileged Codespaces container.

VAULT_VERSION="${VAULT_VERSION:-1.21.4}"
ARCH="$(dpkg --print-architecture)"   # amd64 or arm64
TMPDIR="$(mktemp -d)"

sudo apt-get update
sudo apt-get install -y curl unzip jq

curl -fsSL -o "${TMPDIR}/vault.zip" \
  "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${ARCH}.zip"

unzip -o "${TMPDIR}/vault.zip" -d "${TMPDIR}"
sudo install -m 0755 "${TMPDIR}/vault" /usr/local/bin/vault
rm -rf "${TMPDIR}"

vault version

if [ -f vault.pid ] && kill -0 "$(cat vault.pid)" 2>/dev/null; then
  echo "Vault dev server đã chạy (pid $(cat vault.pid))."
  exit 0
fi

nohup vault server -dev \
  -dev-root-token-id=root \
  -dev-listen-address=127.0.0.1:8200 \
  > vault.log 2>&1 &
echo $! > vault.pid

for i in {1..20}; do
  if VAULT_ADDR=http://127.0.0.1:8200 vault status >/dev/null 2>&1; then
    echo "Vault đã sẵn sàng. VAULT_ADDR=http://127.0.0.1:8200  VAULT_TOKEN=root"
    exit 0
  fi
  sleep 0.25
done

echo "Không khởi động được Vault. Xem vault.log:" >&2
tail -n 50 vault.log >&2
exit 1