#!/usr/bin/env bash
# Default setup: launch `vault server -dev` with a fixed root token,
# wait for the API to come up, and write the PID so `make stop` can kill it.
# Override this file in a lab if you need a custom topology (e.g. compose).
set -euo pipefail

if [ -f vault.pid ] && kill -0 "$(cat vault.pid)" 2>/dev/null; then
  echo "Vault dev server đã chạy (pid $(cat vault.pid))."
  exit 0
fi

nohup vault server -dev \
  -dev-root-token-id=root \
  -dev-listen-address=127.0.0.1:8200 \
  > vault.log 2>&1 &
echo $! > vault.pid

# Wait for the API to accept requests.
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
