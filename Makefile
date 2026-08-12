# openclaw-secure-local-stack — Makefile
#
# Thin, explicit wrappers around the scripts. NOTHING here installs software,
# starts a background service, or touches secrets. Targets that would run a
# foreground process (like `vault-start`) do so only when you invoke them
# directly; the default target just prints help.

SHELL := /bin/sh
VERSION := $(shell cat VERSION 2>/dev/null || echo unknown)

# Prefer shellcheck if present; otherwise `make check` is a friendly no-op.
SHELLCHECK := $(shell command -v shellcheck 2>/dev/null)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help.
	@echo "openclaw-secure-local-stack $(VERSION)"
	@echo
	@echo "Usage: make <target>"
	@echo
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Read docs/INSTALL.md before your first run."

.PHONY: version
version: ## Print the project version.
	@echo $(VERSION)

.PHONY: install
install: ## Plan prerequisite installation (no changes). Use scripts/install --apply to apply.
	@scripts/install

.PHONY: bootstrap
bootstrap: ## Render config, create owner-only state, init the work-memory DB (idempotent).
	@scripts/bootstrap

.PHONY: doctor
doctor: ## Read-only preflight: checks tools, config, permissions (no changes).
	@scripts/doctor

.PHONY: vault-start
vault-start: ## Start the isolated local Vault in the FOREGROUND (Ctrl-C to stop).
	@echo "Starting foreground, loopback-only Vault. Stop with Ctrl-C."
	@scripts/vault-start

.PHONY: vault-bootstrap
vault-bootstrap: ## Guide Vault init/policies/roles (interactive; you hold all secrets).
	@scripts/vault-bootstrap init

.PHONY: work-session
work-session: ## Start a foreground work session (owns Vault + loopback gateway/TUI; Ctrl-C ends it).
	@echo "Starting a foreground, loopback-only work session. Exit the TUI to end it."
	@scripts/work-session

.PHONY: backup
backup: ## Take one age-encrypted Vault snapshot backup (requires a running, unsealed Vault + token).
	@scripts/backup

.PHONY: restore
restore: ## Inspect an encrypted backup (read-only). Pass ARGS='--identity <key> <archive>'; add --restore to restore.
	@scripts/restore $(ARGS)

.PHONY: uninstall
uninstall: ## Plan removal of generated config/tool files (read-only). Use scripts/uninstall --apply to apply.
	@scripts/uninstall

.PHONY: update
update: ## Check for a GitHub release update. Use ARGS='--to vX.Y.Z' to apply.
	@scripts/update $(ARGS)

.PHONY: check
check: ## Lint the shell scripts with shellcheck, if installed.
ifeq ($(SHELLCHECK),)
	@echo "shellcheck not found; skipping. Install it to lint scripts/."
else
	@echo "Linting shell scripts with $(SHELLCHECK)..."
	@$(SHELLCHECK) -x scripts/install scripts/bootstrap scripts/doctor \
		scripts/vault-start scripts/vault-bootstrap scripts/work-session \
		scripts/backup scripts/restore scripts/uninstall scripts/update \
		scripts/ci-local scripts/release scripts/lib/common.sh
endif

.PHONY: test
test: ## Run the dependency-light test-suite against a throwaway HOME (never real HOME).
	@bash tests/run.sh

.PHONY: ci-local
ci-local: ## Run the native-host CI checks (lint + tests). See scripts/ci-local for Docker/Ubuntu.
	@scripts/ci-local native

.PHONY: version-verify
version-verify: ## Validate VERSION (and, on a tag build, that CI_COMMIT_TAG == v<VERSION>).
	@scripts/release verify

.PHONY: package
package: version-verify ## Build a versioned source archive and SHA-256 checksum under dist/.
	@rm -rf dist
	@mkdir -p dist
	@COPYFILE_DISABLE=1 tar --exclude=./.git --exclude=./dist \
		-czf "dist/openclaw-secure-local-stack-$(VERSION).tar.gz" .
	@cd dist && if command -v sha256sum >/dev/null 2>&1; then \
		sha256sum ./*.tar.gz > SHA256SUMS; \
	else \
		shasum -a 256 ./*.tar.gz > SHA256SUMS; \
	fi
	@cat dist/SHA256SUMS

.PHONY: release
release: ## Prepare a release: VERSION + CHANGELOG only (never git). Usage: make release V=0.2.0
	@test -n "$(V)" || { echo "Usage: make release V=X.Y.Z"; exit 2; }
	@scripts/release prepare $(V)

.PHONY: clean
clean: ## Remove local template backups (config/*.bak.*). Never touches secrets/state.
	@echo "Removing config/*.bak.* backups (if any)..."
	@rm -f config/*.bak.* 2>/dev/null || true
	@echo "Done. Runtime state and secrets live outside the repo and are untouched."
