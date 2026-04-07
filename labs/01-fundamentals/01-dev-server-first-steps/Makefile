SHELL := /usr/bin/env bash
export VAULT_ADDR ?= http://127.0.0.1:8200
export VAULT_TOKEN ?= root

.PHONY: setup verify solution reset stop

setup:
	@bash setup.sh

verify:
	@bash verify.sh

solution:
	@bash solution/apply.sh
	@bash verify.sh

reset: stop setup

stop:
	@if [ -f vault.pid ]; then kill $$(cat vault.pid) 2>/dev/null || true; rm -f vault.pid; fi
