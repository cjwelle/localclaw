# shellcheck shell=bash
# 10-dry-run-safety - plan/dry-run modes must change nothing under a temp HOME.
#
# Every command that has a plan/dry-run mode is exercised here against the
# throwaway sandbox HOME. The invariant: after a plan/dry-run, no config, state,
# or workspace artifact exists. Nothing here needs a real Vault or credentials.
. "${LIB_SH}"

CONFIG_DIR="${XDG_CONFIG_HOME}/localclaw"
STATE_DIR="${XDG_STATE_HOME}/localclaw"
WORKSPACE_DIR="${HOME}/openclaw-workspace"
SCRIPTS="$(scripts_dir)"

# --- bootstrap --dry-run creates nothing -----------------------------------
assert_ok "bootstrap --dry-run exits 0" bash "${SCRIPTS}/bootstrap" --dry-run
assert_absent "bootstrap --dry-run left no config dir" "${CONFIG_DIR}"
assert_absent "bootstrap --dry-run left no state dir" "${STATE_DIR}"
assert_absent "bootstrap --dry-run left no workspace" "${WORKSPACE_DIR}"

# --- help output is always safe and exits 0 --------------------------------
for s in bootstrap install vault-bootstrap work-session backup restore uninstall; do
  assert_ok "${s} --help exits 0" bash "${SCRIPTS}/${s}" --help
done

# --- work-session --dry-run starts nothing, mints nothing ------------------
# It only validates; missing tools are warnings, not failures. Its ONE hard
# failure is a stack port already being in use, which is environmental (a real
# local Vault may hold 18200 on a developer Mac). So we assert exit 0 only when
# the ports are free, but ALWAYS assert it created nothing.
ports_free=1
run_common port_is_listening 18200 && ports_free=0
run_common port_is_listening 18789 && ports_free=0
if [ "${ports_free}" -eq 1 ]; then
  assert_ok "work-session --dry-run exits 0 (ports free)" bash "${SCRIPTS}/work-session" --dry-run
else
  t_skip "stack ports busy on host; checking only that dry-run changes nothing"
  bash "${SCRIPTS}/work-session" --dry-run >/dev/null 2>&1 || true
fi
assert_absent "work-session --dry-run left no config dir" "${CONFIG_DIR}"
assert_absent "work-session --dry-run left no state dir" "${STATE_DIR}"

# --- install plan (no --apply) changes nothing -----------------------------
# Only run the real plan when the platform package manager is present; otherwise
# skip (the plan intentionally fails fast without brew/apt-get). Either way it
# must not create config/state.
os="$(uname -s 2>/dev/null || echo unknown)"
run_plan=0
case "${os}" in
  Darwin) have brew && run_plan=1 || t_skip "install plan: Homebrew absent" ;;
  Linux)  have apt-get && run_plan=1 || t_skip "install plan: apt-get absent" ;;
  *)      t_skip "install plan: unsupported OS ${os}" ;;
esac
if [ "${run_plan}" -eq 1 ]; then
  assert_ok "install (plan) exits 0" bash "${SCRIPTS}/install"
fi
assert_absent "install plan left no config dir" "${CONFIG_DIR}"
assert_absent "install plan left no state dir" "${STATE_DIR}"

# --- uninstall plan (no --apply) changes nothing ---------------------------
assert_ok "uninstall (plan) exits 0" bash "${SCRIPTS}/uninstall"
assert_absent "uninstall plan created no config dir" "${CONFIG_DIR}"

t_summary
