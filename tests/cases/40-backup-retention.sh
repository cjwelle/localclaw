# shellcheck shell=bash
# 40-backup-retention - prune_to_count keeps newest N and touches nothing else.
#
# Uses SYNTHETIC files only (no Vault, no age). Backup archive names embed a
# sortable UTC timestamp, so newest-first is a reverse lexical sort. We verify
# that prune_to_count removes the oldest, keeps the newest N, and never removes
# a file that does not match the archive glob.
. "${LIB_SH}"

DIR="${HOME}/synthetic-backups"
mkdir -p "${DIR}"
GLOB='openclaw-vault-*.tar.gz.age'

# 6 synthetic daily archives with increasing timestamps (oldest -> newest).
stamps="20240101T000000Z 20240102T000000Z 20240103T000000Z 20240104T000000Z 20240105T000000Z 20240106T000000Z"
for s in ${stamps}; do
  printf 'ciphertext\n' > "${DIR}/openclaw-vault-${s}.tar.gz.age"
done
# Unrelated files that must survive pruning.
printf 'keep\n' > "${DIR}/README.txt"
printf 'keep\n' > "${DIR}/openclaw-vault-notes.md"

# Keep the newest 4; expect 2 removed.
removed="$(common_value prune_to_count "${DIR}" "${GLOB}" 4)"
assert_eq "prune reported 2 removals" "${removed}" "2"

# The two oldest must be gone; the four newest must remain.
assert_absent "oldest archive removed"        "${DIR}/openclaw-vault-20240101T000000Z.tar.gz.age"
assert_absent "second-oldest archive removed" "${DIR}/openclaw-vault-20240102T000000Z.tar.gz.age"
assert_file   "kept newest-3 archive"         "${DIR}/openclaw-vault-20240104T000000Z.tar.gz.age"
assert_file   "kept newest archive"           "${DIR}/openclaw-vault-20240106T000000Z.tar.gz.age"

# Non-matching files are never touched.
assert_file "unrelated README preserved"      "${DIR}/README.txt"
assert_file "non-archive .md preserved"       "${DIR}/openclaw-vault-notes.md"

# Keeping more than exist removes nothing.
removed2="$(common_value prune_to_count "${DIR}" "${GLOB}" 99)"
assert_eq "keeping more than present removes 0" "${removed2}" "0"

# Keep 0 removes all remaining matching archives.
removed3="$(common_value prune_to_count "${DIR}" "${GLOB}" 0)"
assert_eq "keep=0 removes the remaining 4" "${removed3}" "4"
assert_file "unrelated files still preserved after keep=0" "${DIR}/README.txt"

# A non-numeric keep must be rejected.
assert_fail "reject non-numeric keep" run_common prune_to_count "${DIR}" "${GLOB}" "notanumber"

# Pruning a non-existent directory is a safe no-op returning 0.
removed4="$(common_value prune_to_count "${HOME}/nope-dir" "${GLOB}" 3)"
assert_eq "pruning a missing dir returns 0" "${removed4}" "0"

t_summary
