# shellcheck shell=bash
# 95-release-versioning - scripts/release validates SemVer and gates tags safely.
#
# scripts/release is the canonical version tool. It must:
#   * report the current VERSION,
#   * validate that VERSION is a bare X.Y.Z SemVer,
#   * on a tag build, require CI_COMMIT_TAG to equal 'v<VERSION>' exactly,
#   * prepare a requested version by editing VERSION + CHANGELOG headings only,
#     NEVER invoking git (no commit/tag/push, no auto-increment).
#
# `prepare` mutations are contained in a sandbox COPY of the release files via
# OSLS_RELEASE_ROOT, so the real repo is never modified by this test.
. "${LIB_SH}"

SCRIPTS="$(scripts_dir)"
REL="${SCRIPTS}/release"
VERSION="$(cat "${REPO_DIR}/VERSION" 2>/dev/null | tr -d '[:space:]')"

# --- current + verify against the real (read-only) repo ---------------------
out="$(bash "${REL}" current 2>/dev/null)"
assert_eq "release current prints VERSION" "${out}" "${VERSION}"

assert_ok "verify passes with no tag (format check only)" \
  bash "${REL}" verify
assert_ok "verify passes when CI_COMMIT_TAG == v<VERSION>" \
  env CI_COMMIT_TAG="v${VERSION}" bash "${REL}" verify
assert_fail "verify fails when the tag does not match VERSION" \
  env CI_COMMIT_TAG="v9.9.9" bash "${REL}" verify
assert_fail "verify fails when the tag lacks the 'v' prefix" \
  env CI_COMMIT_TAG="${VERSION}" bash "${REL}" verify

# For this 0.1.0 project the release tag must be exactly v0.1.0.
assert_ok "the current release tag is exactly v0.1.0" \
  env CI_COMMIT_TAG="v0.1.0" bash "${REL}" verify

# --- release must never EXECUTE git ------------------------------------------
# Flag only a git invocation at statement start (`^ git commit ...`). The script
# may still PRINT copy-paste guidance strings that mention git (those are inside
# quoted `log "..."` arguments and are not executed).
if grep -Eq '^[[:space:]]*git[[:space:]]+(commit|tag|push|add|init)' "${REL}"; then
  t_fail "release script executes a git commit/tag/push/add/init call"
else
  t_pass "release script never executes git commit/tag/push/add/init"
fi

# --- prepare: mutate a SANDBOX COPY only ------------------------------------
ROOT="${HOME}/relrepo"
mkdir -p "${ROOT}"
cp "${REPO_DIR}/VERSION" "${ROOT}/VERSION"
cp "${REPO_DIR}/CHANGELOG.md" "${ROOT}/CHANGELOG.md"

assert_ok "prepare 0.2.0 exits 0" \
  env OSLS_RELEASE_ROOT="${ROOT}" bash "${REL}" prepare 0.2.0 --date 2026-09-01
new_ver="$(cat "${ROOT}/VERSION" | tr -d '[:space:]')"
assert_eq "prepare updated VERSION to 0.2.0" "${new_ver}" "0.2.0"

changelog="$(cat "${ROOT}/CHANGELOG.md")"
assert_contains "changelog gained a 0.2.0 heading with the date" "${changelog}" "## [0.2.0] - 2026-09-01"
assert_contains "changelog keeps a fresh Unreleased section" "${changelog}" "## [Unreleased]"

# The real repo VERSION must be untouched by all of the above.
still="$(cat "${REPO_DIR}/VERSION" | tr -d '[:space:]')"
assert_eq "real repo VERSION untouched" "${still}" "${VERSION}"

# --- prepare rejects invalid or non-incrementing versions -------------------
cp "${REPO_DIR}/VERSION" "${ROOT}/VERSION"
cp "${REPO_DIR}/CHANGELOG.md" "${ROOT}/CHANGELOG.md"
assert_fail "prepare rejects a non-SemVer version" \
  env OSLS_RELEASE_ROOT="${ROOT}" bash "${REL}" prepare "not.a.version"
assert_fail "prepare rejects a lower version than current" \
  env OSLS_RELEASE_ROOT="${ROOT}" bash "${REL}" prepare "0.0.9"
unchanged="$(cat "${ROOT}/VERSION" | tr -d '[:space:]')"
assert_eq "sandbox VERSION unchanged after rejected prepare" "${unchanged}" "${VERSION}"

t_summary
