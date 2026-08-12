# shellcheck shell=bash
# 00-syntax - every shipped shell file must parse under `bash -n`.
#
# A syntax error in any script would be a release blocker, so this is the first
# and cheapest gate. It also confirms the sourced library parses on its own.
. "${LIB_SH}"

scripts="
scripts/install
scripts/bootstrap
scripts/vault-bootstrap
scripts/doctor
scripts/vault-start
scripts/work-session
scripts/backup
scripts/restore
scripts/uninstall
scripts/update
scripts/lib/common.sh
scripts/ci-local
scripts/release
tests/run.sh
tests/lib.sh
"

for rel in ${scripts}; do
  f="${REPO_DIR}/${rel}"
  if [ -r "${f}" ]; then
    assert_ok "bash -n parses ${rel}" bash -n "${f}"
  else
    t_fail "expected file is missing: ${rel}"
  fi
done

# Every case in this directory must also parse.
for c in "${REPO_DIR}"/tests/cases/*.sh; do
  [ -e "${c}" ] || continue
  assert_ok "bash -n parses tests/cases/$(basename "${c}")" bash -n "${c}"
done

# The executable scripts must carry an executable bit (work-session launches
# vault-start and backup directly, so a lost +x is a real regression).
for rel in scripts/install scripts/bootstrap scripts/vault-bootstrap \
           scripts/doctor scripts/vault-start scripts/work-session \
           scripts/backup scripts/restore scripts/uninstall scripts/update \
           scripts/ci-local scripts/release tests/run.sh; do
  f="${REPO_DIR}/${rel}"
  if [ -x "${f}" ]; then t_pass "executable bit set: ${rel}"
  else t_fail "not executable: ${rel}"; fi
done

t_summary
