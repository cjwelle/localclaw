#!/usr/bin/env bash
# tests/run.sh - dependency-light test runner for localclaw.
#
# Runs every case in tests/cases/ against a THROWAWAY sandbox HOME. It NEVER
# uses the operator's real HOME, real credentials, a real Vault, or the network.
# Each case gets its own fresh sandbox home so cases cannot interfere with one
# another; the sandbox is removed after every case.
#
# The suite is written for Bash 3.2 (stock macOS) and needs only POSIX-ish
# tools. Cases degrade gracefully (t_skip) when an optional tool (age, sqlite3,
# jq) is absent, so the same suite runs on a bare Ubuntu container and on a Mac.
#
# Usage:
#   tests/run.sh [-v] [case-glob ...]
#
#   -v            verbose: print every passing assertion, not just failures.
#   case-glob     one or more case-name fragments to run a subset, e.g.
#                 `tests/run.sh syntax retention`.
#
# Exit status is 0 only if every case passed.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"
CASES_DIR="${TESTS_DIR}/cases"
COMMON_SH="${REPO_DIR}/scripts/lib/common.sh"
LIB_SH="${TESTS_DIR}/lib.sh"

export REPO_DIR COMMON_SH LIB_SH

TESTS_VERBOSE=0
FILTERS=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -v|--verbose) TESTS_VERBOSE=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    *)  FILTERS="${FILTERS} $1" ;;
  esac
  shift
done
export TESTS_VERBOSE

# ---------------------------------------------------------------------------
# Sandbox root. Everything a case creates lives under here; the real HOME is
# never touched. We refuse to run if we cannot get a private temp directory.
# ---------------------------------------------------------------------------
REAL_HOME="${HOME:-}"
SANDBOX_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/localclaw-tests.XXXXXX")" \
  || { printf 'Unable to create a sandbox temp directory; refusing to run.\n' >&2; exit 1; }
chmod 700 "${SANDBOX_ROOT}" 2>/dev/null || true

# Belt-and-braces: the sandbox must be a real, private temp dir, never the
# operator's home. If anything looks wrong, stop before a single case runs.
case "${SANDBOX_ROOT}" in
  "${REAL_HOME}"|"${REAL_HOME}"/*)
    printf 'Refusing to run: sandbox resolved inside the real HOME.\n' >&2
    rm -rf "${SANDBOX_ROOT}"; exit 1 ;;
  /*) : ;;
  *)  printf 'Refusing to run: sandbox is not an absolute path.\n' >&2
      rm -rf "${SANDBOX_ROOT}"; exit 1 ;;
esac

cleanup_root() { [ -n "${SANDBOX_ROOT:-}" ] && rm -rf "${SANDBOX_ROOT}" 2>/dev/null || true; }
trap cleanup_root EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ---------------------------------------------------------------------------
# Case discovery.
# ---------------------------------------------------------------------------
[ -d "${CASES_DIR}" ] || { printf 'No cases directory: %s\n' "${CASES_DIR}" >&2; exit 1; }

case_matches() {
  # case_matches <path> : true if no filters, or the path matches any filter.
  [ -z "${FILTERS}" ] && return 0
  local f
  for f in ${FILTERS}; do
    case "$1" in *"${f}"*) return 0 ;; esac
  done
  return 1
}

printf '== localclaw test-suite ==\n'
printf 'repo:    %s\n' "${REPO_DIR}"
printf 'sandbox: %s\n' "${SANDBOX_ROOT}"
printf '\n'

total_cases=0
failed_cases=0
ran_cases=0

for case_file in "${CASES_DIR}"/*.sh; do
  [ -e "${case_file}" ] || continue
  case_matches "${case_file}" || continue
  total_cases=$((total_cases + 1))
  ran_cases=$((ran_cases + 1))
  case_name="$(basename "${case_file}" .sh)"

  # A fresh, isolated sandbox HOME for this case. All XDG dirs live under it, so
  # the whole stack points at throwaway locations.
  case_home="${SANDBOX_ROOT}/${case_name}"
  mkdir -p "${case_home}"
  chmod 700 "${case_home}" 2>/dev/null || true

  printf '[case] %s\n' "${case_name}"
  # Run the case in its own process with the sandbox environment. We scrub any
  # inherited Vault credentials so a case can never reach a real Vault.
  (
    HOME="${case_home}"
    XDG_CONFIG_HOME="${case_home}/.config"
    XDG_STATE_HOME="${case_home}/.local/state"
    export HOME XDG_CONFIG_HOME XDG_STATE_HOME
    unset VAULT_TOKEN LOCAL_VAULT_TOKEN VAULT_ADDR VAULT_NAMESPACE \
          VAULT_CACERT VAULT_CAPATH VAULT_CLIENT_CERT VAULT_CLIENT_KEY 2>/dev/null || true
    export REPO_DIR COMMON_SH LIB_SH TESTS_VERBOSE
    exec bash "${case_file}"
  )
  status=$?
  if [ "${status}" -ne 0 ]; then
    failed_cases=$((failed_cases + 1))
    printf '  ** case FAILED (exit %d)\n' "${status}"
  fi
  rm -rf "${case_home}" 2>/dev/null || true
  printf '\n'
done

printf '== summary ==\n'
printf 'cases run: %d   failed: %d\n' "${ran_cases}" "${failed_cases}"
if [ "${ran_cases}" -eq 0 ]; then
  printf 'No cases matched the given filter(s).\n' >&2
  exit 1
fi
[ "${failed_cases}" -eq 0 ] || exit 1
printf 'All cases passed.\n'
exit 0
