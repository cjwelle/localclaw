# shellcheck shell=bash
# 60-uninstall-preservation - uninstall removes generated config, preserves data.
#
# Bootstraps a sandbox, then drives scripts/uninstall. The contract:
#   * plan mode (no --apply) changes nothing;
#   * --apply removes ONLY the generated config directory and preserves Vault
#     data, the work-memory DB, the workspace, and the backup directory;
#   * --apply --purge-data additionally deletes runtime state but STILL preserves
#     the workspace and the backup directory.
# Confirmations are supplied on stdin (never via argv); no Vault is involved.
. "${LIB_SH}"

CONFIG_DIR="${XDG_CONFIG_HOME}/localclaw"
STATE_DIR="${XDG_STATE_HOME}/localclaw"
WORKSPACE_DIR="${HOME}/openclaw-workspace"
VAULT_DATA_DIR="${STATE_DIR}/vault/data"
MEMORY_DIR="${STATE_DIR}/memory"
STACK_CONF="${CONFIG_DIR}/stack.conf"
SCRIPTS="$(scripts_dir)"

# A backup directory the operator "owns" (outside repo/state), with an archive.
BACKUP_DIR="${HOME}/my-backups"
mkdir -p "${BACKUP_DIR}/Daily"
printf 'ciphertext\n' > "${BACKUP_DIR}/Daily/openclaw-vault-20240101T000000Z.tar.gz.age"

# A high, almost-certainly-free Vault port for the sandbox so the --purge-data
# safety check ("refuse while a local Vault is listening") does not trip over a
# real developer Vault holding the default 18200 on the host.
SANDBOX_VAULT_PORT=53219

bootstrap_sandbox() {
  bash "${SCRIPTS}/bootstrap" >/dev/null 2>&1 || return 1
  # Point stack.conf at our backup dir so uninstall reports/preserves it, and at
  # a throwaway Vault port (last assignment wins in load_stack_config).
  printf 'BACKUP_DIR=%s\n' "${BACKUP_DIR}" >> "${STACK_CONF}"
  printf 'VAULT_PORT=%s\n' "${SANDBOX_VAULT_PORT}" >> "${STACK_CONF}"
  # Simulate real runtime state that must be preserved by a plain uninstall.
  # Use inert marker files (never junk in the sqlite path, which a re-bootstrap
  # would try to open and fail on).
  mkdir -p "${VAULT_DATA_DIR}" "${MEMORY_DIR}"
  printf 'raft\n' > "${VAULT_DATA_DIR}/vault.db"
  printf 'marker\n' > "${MEMORY_DIR}/keep-me"
}

# --- Plan mode changes nothing ----------------------------------------------
bootstrap_sandbox || { t_fail "bootstrap failed"; t_summary; exit 1; }
assert_ok "uninstall plan exits 0" bash "${SCRIPTS}/uninstall"
assert_file "plan preserved config dir"    "${CONFIG_DIR}"
assert_file "plan preserved state dir"     "${STATE_DIR}"
assert_file "plan preserved workspace"     "${WORKSPACE_DIR}"

# --- --apply removes generated config, preserves data -----------------------
printf 'UNINSTALL\n' | bash "${SCRIPTS}/uninstall" --apply >/dev/null 2>&1
apply_status=$?
assert_eq "uninstall --apply exits 0" "${apply_status}" "0"
assert_absent "generated config dir removed"     "${CONFIG_DIR}"
assert_file   "Vault Raft data preserved"        "${VAULT_DATA_DIR}/vault.db"
assert_file   "work-memory state preserved"      "${MEMORY_DIR}/keep-me"
assert_file   "workspace preserved"              "${WORKSPACE_DIR}"
assert_file   "backup archive preserved"         "${BACKUP_DIR}/Daily/openclaw-vault-20240101T000000Z.tar.gz.age"

# --- --apply --purge-data deletes state, still preserves workspace/backups ---
# Rebuild a fresh sandbox (config was removed above).
bootstrap_sandbox || { t_fail "re-bootstrap failed"; t_summary; exit 1; }
if run_common port_is_listening "${SANDBOX_VAULT_PORT}"; then
  t_skip "sandbox Vault port ${SANDBOX_VAULT_PORT} unexpectedly busy; skipping purge-data check"
else
  printf 'UNINSTALL\nDELETE DATA\n' | bash "${SCRIPTS}/uninstall" --apply --purge-data >/dev/null 2>&1
  purge_status=$?
  assert_eq "uninstall --apply --purge-data exits 0" "${purge_status}" "0"
  assert_absent "runtime state dir deleted"        "${STATE_DIR}"
  assert_file   "workspace still preserved"        "${WORKSPACE_DIR}"
  assert_file   "backup dir still preserved"       "${BACKUP_DIR}/Daily/openclaw-vault-20240101T000000Z.tar.gz.age"
fi

# --- Wrong confirmation word aborts without removing anything ----------------
bootstrap_sandbox || { t_fail "re-bootstrap failed"; t_summary; exit 1; }
printf 'nope\n' | bash "${SCRIPTS}/uninstall" --apply >/dev/null 2>&1
assert_file "config dir preserved when confirmation mismatches" "${CONFIG_DIR}"

t_summary
