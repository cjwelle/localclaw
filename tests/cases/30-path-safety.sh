# shellcheck shell=bash
# 30-path-safety - validate_safe_dir / validate_backup_dir refuse dangerous paths.
#
# These guards are the last line of defense against a mis-set BACKUP_DIR or a
# hostile argument pointing a removal/write at a system location. They are pure
# functions in common.sh, so we exercise them directly in a subshell (their
# `fail` calls exit, which run_common isolates).
. "${LIB_SH}"

# --- Absolute-path requirement ---------------------------------------------
assert_fail "reject empty dir"            run_common validate_safe_dir ""
assert_fail "reject relative dir"         run_common validate_safe_dir "relative/path"
assert_fail "reject dot-relative dir"     run_common validate_safe_dir "./x"

# --- '..' traversal --------------------------------------------------------
assert_fail "reject .. in middle"         run_common validate_safe_dir "/a/../b"
assert_fail "reject trailing .."          run_common validate_safe_dir "/a/.."
assert_fail "reject leading ../"          run_common validate_safe_dir "../a"
assert_fail "reject embedded .."          run_common validate_safe_dir "/foo..bar"

# --- Bare system / home directories ----------------------------------------
for d in / /bin /sbin /usr /etc /var /opt /boot /dev /proc /sys /root \
         /System /Library /Applications /Users /home; do
  assert_fail "reject system path ${d}" run_common validate_safe_dir "${d}"
done
assert_fail "reject the real HOME itself" run_common validate_safe_dir "${HOME}"

# --- A genuinely safe path is accepted -------------------------------------
assert_ok "accept a safe absolute path" run_common validate_safe_dir "${HOME}/openclaw-backups"

# --- validate_backup_dir additionally refuses repo and state dirs ----------
# BACKUP_DIR must not live inside the repository or the runtime state directory.
# We point OSLS_REPO_DIR/OSLS_STATE_DIR at known values via the environment the
# subshell inherits (common.sh derives them, but also honors explicit values).
assert_fail "backup dir cannot be the repo" \
  run_common validate_backup_dir "${REPO_DIR}/inside"
# The state dir default is under XDG_STATE_HOME; a child of it must be refused.
assert_fail "backup dir cannot be under runtime state" \
  run_common validate_backup_dir "${XDG_STATE_HOME}/localclaw/sub"
assert_ok "accept a safe backup dir" \
  run_common validate_backup_dir "${HOME}/openclaw-backups"

# --- age recipient validation ----------------------------------------------
good_recip="${HOME}/recipient.good"
bad_recip="${HOME}/recipient.bad"
printf 'age1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsxu2rk\n' > "${good_recip}"
printf 'this is not an age recipient\n' > "${bad_recip}"
assert_ok "accept a well-formed age recipient file" \
  run_common validate_age_recipient_file "${good_recip}"
assert_fail "reject a malformed age recipient file" \
  run_common validate_age_recipient_file "${bad_recip}"
assert_fail "reject a missing age recipient file" \
  run_common validate_age_recipient_file "${HOME}/nope.recipient"

t_summary
