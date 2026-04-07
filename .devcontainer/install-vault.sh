#!/usr/bin/env bash
set -euo pipefail

# Install Vault by downloading the official binary zip directly.
# We avoid the apt package because its postinstall sets the IPC_LOCK file
# capability on /usr/bin/vault, which causes "Operation not permitted" when
# executing the binary inside an unprivileged Codespaces container.

VAULT_VERSION="${VAULT_VERSION:-1.17.6}"
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
