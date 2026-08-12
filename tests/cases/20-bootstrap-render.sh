# shellcheck shell=bash
# 20-bootstrap-render - bootstrap renders config and is idempotent.
#
# Runs the REAL bootstrap against the sandbox HOME (no Vault, no secrets). It
# renders vault.hcl/openclaw.json, seeds stack.conf/secrets.map, creates
# owner-only dirs, and (if sqlite3 is present) initializes the memory DB. A
# second run must be byte-for-byte idempotent: no rewrite, no new .bak files.
. "${LIB_SH}"

CONFIG_DIR="${XDG_CONFIG_HOME}/localclaw"
STATE_DIR="${XDG_STATE_HOME}/localclaw"
WORKSPACE_DIR="${HOME}/openclaw-workspace"
VAULT_HCL="${CONFIG_DIR}/vault.hcl"
OPENCLAW_JSON="${CONFIG_DIR}/openclaw.json"
STACK_CONF="${CONFIG_DIR}/stack.conf"
SECRETS_MAP="${CONFIG_DIR}/secrets.map"
MEMORY_DB="${STATE_DIR}/memory/work_memory.sqlite"
SCRIPTS="$(scripts_dir)"

assert_ok "first bootstrap exits 0" bash "${SCRIPTS}/bootstrap"

assert_file "rendered vault.hcl exists" "${VAULT_HCL}"
assert_file "rendered openclaw.json exists" "${OPENCLAW_JSON}"
assert_file "seeded stack.conf exists" "${STACK_CONF}"
assert_file "seeded secrets.map exists" "${SECRETS_MAP}"

# Rendered files must have NO unresolved @PLACEHOLDER@ tokens.
if grep -Eq '@[A-Z][A-Z0-9_]*@' "${VAULT_HCL}"; then
  t_fail "vault.hcl still has unresolved @PLACEHOLDER@ tokens"
else
  t_pass "vault.hcl has no unresolved placeholders"
fi
if grep -Eq '@[A-Z][A-Z0-9_]*@' "${OPENCLAW_JSON}"; then
  t_fail "openclaw.json still has unresolved @PLACEHOLDER@ tokens"
else
  t_pass "openclaw.json has no unresolved placeholders"
fi

# Rendered vault.hcl must reflect the sample defaults (loopback host/port).
hcl="$(cat "${VAULT_HCL}")"
assert_contains "vault.hcl binds loopback host" "${hcl}" "127.0.0.1:18200"
assert_contains "vault.hcl points storage at the sandbox state dir" "${hcl}" "${STATE_DIR}"

# openclaw.json must be valid JSON when jq is available.
if have jq; then
  assert_ok "openclaw.json is valid JSON" jq -e . "${OPENCLAW_JSON}"
  assert_ok "openclaw.json selects local loopback mode" \
    jq -e '.gateway.mode == "local" and .gateway.bind == "loopback"' "${OPENCLAW_JSON}"
  assert_ok "openclaw.json uses the generated workspace" \
    jq -e --arg workspace "${WORKSPACE_DIR}" '.agents.defaults.workspace == $workspace' "${OPENCLAW_JSON}"
else
  t_skip "jq absent: not validating openclaw.json as JSON"
fi

# Owner-only perms on the config/state dirs (best-effort: some filesystems drop
# mode bits, so only assert when the mode is readable and not the default).
for d in "${CONFIG_DIR}" "${STATE_DIR}"; do
  mode="$(ls -ld "${d}" 2>/dev/null | awk '{print $1}')"
  case "${mode}" in
    drwx------*) t_pass "owner-only dir: ${d}" ;;
    *)           t_fail "not owner-only: ${d} (${mode})" ;;
  esac
done

# Memory DB (only if sqlite3 is available).
if have sqlite3; then
  assert_file "work-memory DB initialized" "${MEMORY_DB}"
  # Schema must contain the expected tables.
  tables="$(sqlite3 "${MEMORY_DB}" '.tables' 2>/dev/null || true)"
  assert_contains "schema has action_log table" "${tables}" "action_log"
  assert_contains "schema has follow_up table" "${tables}" "follow_up"
else
  t_skip "sqlite3 absent: not initializing/validating the memory DB"
fi

# --- Idempotency: a second run must not rewrite or accumulate .bak files -----
vault_before="$(cat "${VAULT_HCL}")"
sum_before="$(shasum "${VAULT_HCL}" 2>/dev/null | awk '{print $1}')"
assert_ok "second bootstrap exits 0" bash "${SCRIPTS}/bootstrap"
sum_after="$(shasum "${VAULT_HCL}" 2>/dev/null | awk '{print $1}')"
assert_eq "vault.hcl is byte-identical after re-render" "${sum_after}" "${sum_before}"

# No timestamped backups should have been created for byte-identical renders.
bak_count=0
for b in "${CONFIG_DIR}"/*.bak.*; do
  [ -e "${b}" ] || continue
  bak_count=$((bak_count + 1))
done
assert_eq "no .bak churn on idempotent re-render" "${bak_count}" "0"

# --- Nothing was written INSIDE the repository ------------------------------
# The repo must never gain a rendered stack.conf/vault.hcl/etc.
for leftover in stack.conf vault.hcl openclaw.json secrets.map; do
  assert_absent "repo config/ has no rendered ${leftover}" "${REPO_DIR}/config/${leftover}"
done

t_summary
