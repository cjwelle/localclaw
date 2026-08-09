# shellcheck shell=bash
# tests/lib.sh - tiny, dependency-light assertion helpers for the test-suite.
#
# This file is SOURCED by tests/run.sh and by every case in tests/cases/. It is
# written for Bash 3.2 (the stock macOS shell): no associative arrays, no
# `mapfile`, no Bash 4+ features. It has no external dependencies beyond the
# POSIX tools the stack itself relies on.
#
# Contract expected from the environment (set by tests/run.sh):
#   REPO_DIR    absolute path to the repository under test
#   HOME        a THROWAWAY sandbox home (never the operator's real home)
#   COMMON_SH   absolute path to scripts/lib/common.sh
#
# Nothing here reads or writes real credentials, and no case may touch the real
# HOME: run.sh points HOME at a temp sandbox and refuses to run otherwise.

# Per-case counters. Each case is its own `bash` process, so plain shell
# variables are sufficient and isolated.
_T_PASS=0
_T_FAIL=0
: "${TESTS_VERBOSE:=0}"

t_pass() {
  _T_PASS=$((_T_PASS + 1))
  [ "${TESTS_VERBOSE}" = "1" ] && printf '    ok:   %s\n' "$*"
  return 0
}

t_fail() {
  _T_FAIL=$((_T_FAIL + 1))
  printf '    FAIL: %s\n' "$*" >&2
  return 1
}

t_skip() {
  printf '    skip: %s\n' "$*" >&2
  return 0
}

# assert_ok "desc" cmd args...   -- passes if the command exits 0.
assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then t_pass "${desc}"; else t_fail "${desc} (command failed: $*)"; fi
}

# assert_fail "desc" cmd args... -- passes if the command exits NON-zero.
assert_fail() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then t_fail "${desc} (expected non-zero exit)"; else t_pass "${desc}"; fi
}

assert_file()   { [ -e "$2" ] && t_pass "$1" || t_fail "$1 (missing path: $2)"; }
assert_absent() { [ ! -e "$2" ] && t_pass "$1" || t_fail "$1 (unexpected path: $2)"; }
assert_dir()    { [ -d "$2" ] && t_pass "$1" || t_fail "$1 (missing dir: $2)"; }

assert_eq() {
  # assert_eq "desc" actual expected
  if [ "$2" = "$3" ]; then t_pass "$1"; else t_fail "$1 (got '$2', want '$3')"; fi
}

assert_ne() {
  if [ "$2" != "$3" ]; then t_pass "$1"; else t_fail "$1 (both '$2')"; fi
}

# assert_contains "desc" haystack needle
assert_contains() {
  case "$2" in
    *"$3"*) t_pass "$1" ;;
    *)      t_fail "$1 (substring not found: '$3')" ;;
  esac
}

# assert_not_contains "desc" haystack needle
assert_not_contains() {
  case "$2" in
    *"$3"*) t_fail "$1 (unexpected substring: '$3')" ;;
    *)      t_pass "$1" ;;
  esac
}

# Print a case summary line and return non-zero if any assertion failed.
t_summary() {
  printf '  -> %d passed, %d failed\n' "${_T_PASS}" "${_T_FAIL}"
  [ "${_T_FAIL}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Helpers shared across cases.
# ---------------------------------------------------------------------------

# have <bin> : is a tool on PATH?
have() { command -v "$1" >/dev/null 2>&1; }

# run_common <fn> [args...] : source common.sh in a SUBSHELL and call one of its
# functions. common.sh's `fail` calls `exit 1`, so running it in a subshell lets
# us assert refusal without killing the case. All output is suppressed.
run_common() {
  ( . "${COMMON_SH}" >/dev/null 2>&1; "$@" ) >/dev/null 2>&1
}

# common_value <fn> [args...] : like run_common but echoes the function's stdout
# (used for helpers such as prune_to_count that print a value).
common_value() {
  ( . "${COMMON_SH}" >/dev/null 2>&1; "$@" ) 2>/dev/null
}

# A path to the scripts directory of the repo under test.
scripts_dir() { printf '%s/scripts' "${REPO_DIR}"; }
