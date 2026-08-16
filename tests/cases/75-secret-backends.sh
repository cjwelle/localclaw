#!/usr/bin/env bash
# 75-secret-backends - validate the explicit Vault/password-manager modes.
. "${LIB_SH}"

assert_ok "common loader accepts SECRET_BACKEND=vault" bash -c \
  '. "$1"; printf "SECRET_BACKEND=vault\n" >"$2"; load_stack_config "$2"; test "$SECRET_BACKEND" = vault' \
  _ "${COMMON_SH}" "${HOME}/vault.conf"

assert_ok "common loader accepts SECRET_BACKEND=password-manager" bash -c \
  '. "$1"; printf "SECRET_BACKEND=password-manager\nCREDENTIAL_PROVIDER=bitwarden\n" >"$2"; load_stack_config "$2"; test "$SECRET_BACKEND" = password-manager && test "$CREDENTIAL_PROVIDER" = bitwarden' \
  _ "${COMMON_SH}" "${HOME}/pm.conf"

work_session_source="$(cat "${REPO_DIR}/scripts/work-session")"
assert_contains "work-session implements Vault map validation" "${work_session_source}" "Invalid Vault KV path"
assert_contains "work-session implements provider map validation" "${work_session_source}" "Invalid password-manager reference"
assert_contains "password-manager work-session skips Vault" "${work_session_source}" "run_password_manager_session"

t_summary
