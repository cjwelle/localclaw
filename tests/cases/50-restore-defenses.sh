# shellcheck shell=bash
# 50-restore-defenses - restore refuses traversal/link/checksum/identity attacks.
#
# Builds SYNTHETIC age-encrypted archives (never a real Vault snapshot) and
# drives scripts/restore in its default read-only mode. We assert it:
#   * accepts a well-formed archive (inspect-only, exits 0),
#   * refuses a member whose name contains '..' (traversal guard),
#   * refuses a symlink/link member (type guard),
#   * refuses a tampered file (SHA256SUMS mismatch),
#   * refuses an archive missing MANIFEST.txt,
#   * refuses an archive whose MANIFEST claims a different app,
#   * refuses a wrong age identity (decryption failure).
#
# Requires age + age-keygen + tar; skips cleanly if any is missing. A tiny stub
# `vault` is placed on PATH so the final read-only `snapshot inspect` step has a
# binary to call (the refusal cases fail long before it runs).
. "${LIB_SH}"

if ! have age || ! have age-keygen || ! have tar; then
  t_skip "age/age-keygen/tar not all present; skipping restore-defense case"
  t_summary
  exit 0
fi

APP="localclaw"
SCRIPTS="$(scripts_dir)"
WORK="${HOME}/restore-work"
mkdir -p "${WORK}"

# --- Stub vault on PATH (only used by the read-only inspect step) -----------
BIN="${HOME}/bin"
mkdir -p "${BIN}"
cat > "${BIN}/vault" <<'STUB'
#!/usr/bin/env bash
# Test stub: accept any 'operator raft snapshot inspect ...' and succeed.
exit 0
STUB
chmod +x "${BIN}/vault"
PATH="${BIN}:${PATH}"
export PATH

sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}

# --- age identities ---------------------------------------------------------
ID="${WORK}/id.age"
WRONG_ID="${WORK}/wrong.age"
age-keygen -o "${ID}" >/dev/null 2>&1       || { t_fail "age-keygen failed"; t_summary; exit 1; }
age-keygen -o "${WRONG_ID}" >/dev/null 2>&1 || { t_fail "age-keygen failed"; t_summary; exit 1; }
RECIP="$(age-keygen -y "${ID}" 2>/dev/null)"
[ -n "${RECIP}" ] || { t_fail "could not derive age recipient"; t_summary; exit 1; }

# encrypt_stage <stage-dir> <out.age> : tar the stage and age-encrypt it.
encrypt_stage() {
  tar -C "$1" -czf - . 2>/dev/null | age -r "${RECIP}" -o "$2" 2>/dev/null
}

# build_valid_stage <stage-dir> : a well-formed archive the restore trusts.
build_valid_stage() {
  local stage="$1"
  mkdir -p "${stage}/vault" "${stage}/config"
  printf 'SYNTHETIC-SNAPSHOT\n' > "${stage}/vault/raft.snap"
  printf 'profile=work\n'        > "${stage}/config/stack.conf"
  local snap_sha; snap_sha="$(sha "${stage}/vault/raft.snap")"
  {
    printf 'archive_schema=1\n'
    printf 'app=%s\n' "${APP}"
    printf 'created_utc=20240101T000000Z\n'
    printf 'snapshot_sha256=%s\n' "${snap_sha}"
  } > "${stage}/MANIFEST.txt"
  # SHA256SUMS: "<sha>  ./relpath" for every file except SHA256SUMS itself.
  ( cd "${stage}" && find . -type f ! -name 'SHA256SUMS' | LC_ALL=C sort | while IFS= read -r rel; do
      printf '%s  %s\n' "$(sha "${rel}")" "${rel}"
    done ) > "${stage}/SHA256SUMS"
}

# --- 1) Valid archive: inspect-only, exits 0 --------------------------------
S1="${WORK}/s-valid"; A1="${WORK}/valid.tar.gz.age"
build_valid_stage "${S1}"
encrypt_stage "${S1}" "${A1}"
assert_ok "valid archive passes read-only inspect" \
  bash "${SCRIPTS}/restore" --identity "${ID}" "${A1}"

# --- 2) Traversal: a member name containing '..' ----------------------------
S2="${WORK}/s-trav"; A2="${WORK}/trav.tar.gz.age"
build_valid_stage "${S2}"
printf 'x\n' > "${S2}/escape..payload"          # name contains '..' -> refused
encrypt_stage "${S2}" "${A2}"
assert_fail "refuse archive with '..' in a member name" \
  bash "${SCRIPTS}/restore" --identity "${ID}" "${A2}"

# --- 3) Link member: a symlink inside the archive ---------------------------
S3="${WORK}/s-link"; A3="${WORK}/link.tar.gz.age"
build_valid_stage "${S3}"
ln -s /etc/passwd "${S3}/config/link-to-passwd" 2>/dev/null || true
if [ -L "${S3}/config/link-to-passwd" ]; then
  encrypt_stage "${S3}" "${A3}"
  assert_fail "refuse archive containing a symlink member" \
    bash "${SCRIPTS}/restore" --identity "${ID}" "${A3}"
else
  t_skip "could not create a symlink; skipping link-member check"
fi

# --- 4) Checksum tamper: valid structure, corrupted content -----------------
S4="${WORK}/s-tamper"; A4="${WORK}/tamper.tar.gz.age"
build_valid_stage "${S4}"
printf 'TAMPERED-AFTER-SUMS\n' > "${S4}/vault/raft.snap"   # sha no longer matches
encrypt_stage "${S4}" "${A4}"
assert_fail "refuse archive whose checksum does not match SHA256SUMS" \
  bash "${SCRIPTS}/restore" --identity "${ID}" "${A4}"

# --- 5) Missing MANIFEST ----------------------------------------------------
S5="${WORK}/s-nomanifest"; A5="${WORK}/nomanifest.tar.gz.age"
build_valid_stage "${S5}"
rm -f "${S5}/MANIFEST.txt"
encrypt_stage "${S5}" "${A5}"
assert_fail "refuse archive missing MANIFEST.txt" \
  bash "${SCRIPTS}/restore" --identity "${ID}" "${A5}"

# --- 6) Wrong app in MANIFEST -----------------------------------------------
S6="${WORK}/s-wrongapp"; A6="${WORK}/wrongapp.tar.gz.age"
build_valid_stage "${S6}"
# Rewrite the app line then refresh SHA256SUMS so only the app identity differs.
sed 's/^app=.*/app=some-other-project/' "${S6}/MANIFEST.txt" > "${S6}/MANIFEST.new"
mv "${S6}/MANIFEST.new" "${S6}/MANIFEST.txt"
( cd "${S6}" && find . -type f ! -name 'SHA256SUMS' | LC_ALL=C sort | while IFS= read -r rel; do
    printf '%s  %s\n' "$(sha "${rel}")" "${rel}"
  done ) > "${S6}/SHA256SUMS"
encrypt_stage "${S6}" "${A6}"
assert_fail "refuse archive whose MANIFEST names a different app" \
  bash "${SCRIPTS}/restore" --identity "${ID}" "${A6}"

# --- 7) Wrong identity: decryption must fail --------------------------------
assert_fail "refuse to decrypt a valid archive with the wrong identity" \
  bash "${SCRIPTS}/restore" --identity "${WRONG_ID}" "${A1}"

# --- 8) Missing archive / missing identity paths ----------------------------
assert_fail "refuse a non-existent archive path" \
  bash "${SCRIPTS}/restore" --identity "${ID}" "${WORK}/does-not-exist.tar.gz.age"
assert_fail "refuse a non-existent identity path" \
  bash "${SCRIPTS}/restore" --identity "${WORK}/no-such-id" "${A1}"

t_summary
