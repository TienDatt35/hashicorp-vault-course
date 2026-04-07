# Lab Makefile — every lab implements the same four targets so the learner
# experience is identical across the course. Override SETUP/VERIFY/SOLUTION
# behavior in the per-lab files (setup.sh, verify.sh, solution/apply.sh).

SHELL := /usr/bin/env bash
export VAULT_ADDR ?= http://127.0.0.1:8200
export VAULT_TOKEN ?= root

.PHONY: setup verify solution reset stop

setup: ## Start a dev Vault server in the background
	@bash setup.sh

verify: ## Run the assertions in verify.sh
	@bash verify.sh

solution: ## Apply the reference answer then verify (used by CI)
	@bash solution/apply.sh
	@bash verify.sh

reset: stop setup ## Tear down and restart fresh

stop: ## Stop the dev Vault server if running
	@if [ -f vault.pid ]; then kill $$(cat vault.pid) 2>/dev/null || true; rm -f vault.pid; fi
