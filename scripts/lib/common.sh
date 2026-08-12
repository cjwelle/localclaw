# shellcheck shell=bash
# shellcheck disable=SC2034 # shared variables are consumed by sourcing scripts
# common.sh - shared helpers for the localclaw scripts.
#
# This file is sourced, never executed. It is written to be portable across
# Bash 3.2 (the macOS system Bash) and modern Bash. It intentionally avoids
# associative arrays, `mapfile`, and other Bash 4+ only features.
#
# Nothing in this library reads, prints, or persists secret material.

# ---------------------------------------------------------------------------
# Strict-ish mode. Callers may already have set these; setting them again is
# harmless and keeps sourced-in-isolation usage safe.
# ---------------------------------------------------------------------------
set -o pipefail 2>/dev/null || true

APP_NAME="localclaw"

# ---------------------------------------------------------------------------
# Paths. Every location is overridable through the environment so that the
# test-suite can point the whole stack at a throwaway HOME without touching
# the real one.
# ---------------------------------------------------------------------------
: "${HOME:?HOME must be set}"
: "${XDG_CONFIG_HOME:=${HOME}/.config}"
: "${XDG_STATE_HOME:=${HOME}/.local/state}"

: "${OSLS_CONFIG_DIR:=${XDG_CONFIG_HOME}/${APP_NAME}}"
: "${OSLS_STATE_DIR:=${XDG_STATE_HOME}/${APP_NAME}}"
: "${OSLS_WORKSPACE_DIR:=${HOME}/openclaw-workspace}"

# Resolve the repository root from the location of this library. common.sh
# lives in <repo>/scripts/lib/common.sh.
_common_self="${BASH_SOURCE[0]:-$0}"
OSLS_LIB_DIR="$(cd "$(dirname "${_common_self}")" && pwd)"
OSLS_SCRIPTS_DIR="$(cd "${OSLS_LIB_DIR}/.." && pwd)"
OSLS_REPO_DIR="$(cd "${OSLS_SCRIPTS_DIR}/.." && pwd)"
unset _common_self

# Generated runtime config files.
OSLS_STACK_CONF="${OSLS_CONFIG_DIR}/stack.conf"
OSLS_SECRETS_MAP="${OSLS_CONFIG_DIR}/secrets.map"
OSLS_VAULT_HCL="${OSLS_CONFIG_DIR}/vault.hcl"
OSLS_OPENCLAW_JSON="${OSLS_CONFIG_DIR}/openclaw.json"
OSLS_AGE_RECIPIENT_FILE="${OSLS_CONFIG_DIR}/vault-backup-age-recipient"
OSLS_LAST_BACKUP_FILE="${OSLS_CONFIG_DIR}/vault-backup-last-success"

# Runtime state.
OSLS_VAULT_DATA_DIR="${OSLS_STATE_DIR}/vault/data"
OSLS_VAULT_HOME="${OSLS_STATE_DIR}/vault/runtime-home"
OSLS_MEMORY_DB="${OSLS_STATE_DIR}/memory/work_memory.sqlite"
OSLS_LOG_DIR="${OSLS_STATE_DIR}/logs"
OSLS_OPENCLAW_STATE_DIR="${OSLS_STATE_DIR}/openclaw"

# ---------------------------------------------------------------------------
# Non-secret stack defaults. These are overridden by stack.conf when present.
# ---------------------------------------------------------------------------
VAULT_HOST="127.0.0.1"
VAULT_PORT="18200"
VAULT_CLUSTER_PORT="18201"
VAULT_NODE_ID="openclaw-local-1"
VAULT_KV_MOUNT="local"
VAULT_ADMIN_USER="admin"
OPENCLAW_PROFILE="work"
OPENCLAW_PORT="18789"
OPENCLAW_BIN="openclaw"
VAULT_BIN="vault"
AGE_BIN="age"
AGE_KEYGEN_BIN="age-keygen"
# Optional password-manager adapter used only for short-lived backup-key
# retrieval. The reference is provider-specific and is never secret by itself.
CREDENTIAL_PROVIDER="none"
BACKUP_IDENTITY_REF=""
# Generic backup destination. Deliberately empty: the operator must choose a
# directory (local or cloud-synced) during bootstrap. No tenant is baked in.
BACKUP_DIR=""
# Unseal parameters used only as guidance during vault-bootstrap init.
VAULT_KEY_SHARES="5"
VAULT_KEY_THRESHOLD="3"
# Retention (daily/weekly encrypted archives).
BACKUP_KEEP_DAILY="14"
BACKUP_KEEP_WEEKLY="8"
# Work-memory retention window (used by sql templating / docs only).
MEMORY_RETENTION="30 days"

# ---------------------------------------------------------------------------
# Vault policy and token-role names. These are NOT operator-tunable through
# stack.conf: they must stay in sync with the files in policies/ and with the
# roles created by scripts/vault-bootstrap. Kept here so every script agrees.
# ---------------------------------------------------------------------------
VAULT_ADMIN_POLICY="admin"
VAULT_AGENT_POLICY="agent"
VAULT_BACKUP_POLICY="backup"
VAULT_AGENT_ROLE="agent-session"
VAULT_BACKUP_ROLE="backup-session"

# ---------------------------------------------------------------------------
# Output helpers. All diagnostics go to stderr so stdout stays clean for
# machine-readable values when a caller wants them.
# ---------------------------------------------------------------------------
_osls_is_tty() { [ -t 2 ]; }

log()  { printf '%s\n' "$*" >&2; }
info() { printf '[*] %s\n' "$*" >&2; }
ok()   { printf '[+] %s\n' "$*" >&2; }
warn() { printf '[!] %s\n' "$*" >&2; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Small portability shims.
# ---------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

sha256_of() {
  # Print the hex sha256 of a file, portably.
  if have shasum; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif have sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  else
    fail "Neither shasum nor sha256sum is available."
  fi
}

detect_os() {
  # Echoes one of: macos, linux, unknown
  case "$(uname -s 2>/dev/null)" in
    Darwin) printf 'macos\n' ;;
    Linux)  printf 'linux\n' ;;
    *)      printf 'unknown\n' ;;
  esac
}

vault_addr() { printf 'http://%s:%s\n' "${VAULT_HOST}" "${VAULT_PORT}"; }

# ---------------------------------------------------------------------------
# Configuration loading. stack.conf is a restricted KEY=VALUE file; we do not
# `source` arbitrary shell, we parse a known allow-list of keys instead.
# ---------------------------------------------------------------------------
load_stack_config() {
  local file="${1:-${OSLS_STACK_CONF}}"
  [ -r "${file}" ] || return 0

  local line key value
  while IFS= read -r line || [ -n "${line}" ]; do
    # Strip comments and surrounding whitespace.
    case "${line}" in
      ''|'#'*) continue ;;
    esac
    key="${line%%=*}"
    value="${line#*=}"
    # Trim whitespace around the key.
    key="$(printf '%s' "${key}" | tr -d '[:space:]')"
    # Strip a single pair of surrounding quotes from the value.
    case "${value}" in
      \"*\") value="${value#\"}"; value="${value%\"}" ;;
      \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac
    case "${key}" in
      VAULT_HOST)          VAULT_HOST="${value}" ;;
      VAULT_PORT)          VAULT_PORT="${value}" ;;
      VAULT_CLUSTER_PORT)  VAULT_CLUSTER_PORT="${value}" ;;
      VAULT_NODE_ID)       VAULT_NODE_ID="${value}" ;;
      VAULT_KV_MOUNT)      VAULT_KV_MOUNT="${value}" ;;
      VAULT_ADMIN_USER)    VAULT_ADMIN_USER="${value}" ;;
      OPENCLAW_PROFILE)    OPENCLAW_PROFILE="${value}" ;;
      OPENCLAW_PORT)       OPENCLAW_PORT="${value}" ;;
      OPENCLAW_BIN)        OPENCLAW_BIN="${value}" ;;
      VAULT_BIN)           VAULT_BIN="${value}" ;;
      AGE_BIN)             AGE_BIN="${value}" ;;
      AGE_KEYGEN_BIN)      AGE_KEYGEN_BIN="${value}" ;;
      CREDENTIAL_PROVIDER) CREDENTIAL_PROVIDER="${value}" ;;
      BACKUP_IDENTITY_REF) BACKUP_IDENTITY_REF="${value}" ;;
      BACKUP_DIR)          BACKUP_DIR="${value}" ;;
      VAULT_KEY_SHARES)    VAULT_KEY_SHARES="${value}" ;;
      VAULT_KEY_THRESHOLD) VAULT_KEY_THRESHOLD="${value}" ;;
      BACKUP_KEEP_DAILY)   BACKUP_KEEP_DAILY="${value}" ;;
      BACKUP_KEEP_WEEKLY)  BACKUP_KEEP_WEEKLY="${value}" ;;
      MEMORY_RETENTION)    MEMORY_RETENTION="${value}" ;;
      *) warn "Ignoring unknown stack.conf key: ${key}" ;;
    esac
  done < "${file}"
}

# ---------------------------------------------------------------------------
# Path safety. Used everywhere an operator-supplied directory is accepted.
# ---------------------------------------------------------------------------
validate_safe_dir() {
  local dir="$1" label="${2:-directory}" forbidden
  [ -n "${dir}" ] || fail "${label} is empty."
  case "${dir}" in
    /*) : ;;
    *)  fail "${label} must be an absolute path: ${dir}" ;;
  esac
  case "${dir}" in *..*) fail "${label} must not contain '..': ${dir}" ;; esac
  for forbidden in / /bin /sbin /usr /etc /var /opt /boot /dev /proc /sys \
                   /root /System /Library /Applications /Users /home "${HOME}"; do
    if [ "${dir}" = "${forbidden}" ]; then
      fail "${label} refuses a dangerous system path: ${dir}"
    fi
  done
}

# Validate a backup directory specifically: it must be safe and, if it exists,
# be a writable directory. It must not be inside the repo or the state dir.
validate_backup_dir() {
  local dir="$1"
  validate_safe_dir "${dir}" "BACKUP_DIR"
  case "${dir}" in
    "${OSLS_REPO_DIR}"|"${OSLS_REPO_DIR}"/*)
      fail "BACKUP_DIR must not live inside the repository: ${dir}" ;;
    "${OSLS_STATE_DIR}"|"${OSLS_STATE_DIR}"/*)
      fail "BACKUP_DIR must not live inside the runtime state directory: ${dir}" ;;
  esac
  if [ -e "${dir}" ]; then
    [ -d "${dir}" ] || fail "BACKUP_DIR exists but is not a directory: ${dir}"
    [ -w "${dir}" ] || fail "BACKUP_DIR is not writable: ${dir}"
  fi
}

# ---------------------------------------------------------------------------
# Template rendering. Placeholders look like @NAME@. Substitution is done with
# Bash parameter expansion (3.2-safe) so no external tool is required, and we
# refuse to emit a file that still contains an unresolved @NAME@ token.
# ---------------------------------------------------------------------------
render_template() {
  local src="$1" dst="$2"; shift 2
  [ -r "${src}" ] || fail "Template not found: ${src}"
  local content key value
  content="$(cat "${src}")"
  while [ "$#" -ge 2 ]; do
    key="$1"; value="$2"; shift 2
    content="${content//@${key}@/${value}}"
  done
  # Refuse to write unresolved placeholders of the form @UPPER_NAME@.
  if printf '%s' "${content}" | grep -Eq '@[A-Z][A-Z0-9_]*@'; then
    local leftover
    leftover="$(printf '%s' "${content}" | grep -Eo '@[A-Z][A-Z0-9_]*@' | sort -u | tr '\n' ' ')"
    fail "Template ${src} still has unresolved placeholders: ${leftover}"
  fi
  local dstdir; dstdir="$(dirname "${dst}")"
  [ -d "${dstdir}" ] || mkdir -p "${dstdir}"
  # If the rendered content is byte-identical to what is already there, do
  # nothing: no rewrite and no backup churn. Re-rendering is thus idempotent.
  if [ -f "${dst}" ] && [ "$(cat "${dst}")" = "${content}" ]; then
    return 0
  fi
  # Preserve an existing (differing) file as a timestamped backup first.
  backup_existing_file "${dst}"
  ( umask 077; printf '%s\n' "${content}" > "${dst}" )
}

# Create a timestamped copy of an existing file before it is replaced.
backup_existing_file() {
  local f="$1"
  [ -e "${f}" ] || return 0
  local stamp; stamp="$(date +%Y%m%dT%H%M%S)"
  local bak="${f}.bak.${stamp}"
  cp -p "${f}" "${bak}"
  ( umask 077; chmod 600 "${bak}" 2>/dev/null || true )
  warn "Preserved existing $(basename "${f}") as $(basename "${bak}")"
}

# ---------------------------------------------------------------------------
# Retention: keep the newest N files matching a basename glob in a directory.
# File names embed sortable UTC timestamps, so a reverse lexical sort is a
# newest-first ordering. Only matching names are ever removed. Prints the
# number removed on stdout.
# ---------------------------------------------------------------------------
prune_to_count() {
  local dir="$1" pattern="$2" keep="$3"
  local removed=0 count=0 f listfile
  [ -d "${dir}" ] || { printf '0\n'; return 0; }
  case "${keep}" in ''|*[!0-9]*) fail "prune_to_count: keep must be numeric" ;; esac

  listfile="$(mktemp "${TMPDIR:-/tmp}/osls-prune.XXXXXX")"
  # -name matches the basename only, so directory paths with spaces are safe.
  find "${dir}" -maxdepth 1 -type f -name "${pattern}" 2>/dev/null \
    | LC_ALL=C sort -r > "${listfile}"
  while IFS= read -r f; do
    [ -n "${f}" ] || continue
    count=$((count + 1))
    if [ "${count}" -gt "${keep}" ]; then
      rm -f "${f}" && removed=$((removed + 1))
    fi
  done < "${listfile}"
  rm -f "${listfile}"
  printf '%s\n' "${removed}"
}

# ---------------------------------------------------------------------------
# Vault helpers. These never accept or print a token on the command line; a
# token is passed only through the LOCAL_VAULT_TOKEN environment variable by
# the caller and exported to VAULT_TOKEN transiently for a single command.
# ---------------------------------------------------------------------------
vault_env_reset() {
  unset VAULT_AGENT_ADDR VAULT_NAMESPACE VAULT_CACERT VAULT_CAPATH \
        VAULT_CLIENT_CERT VAULT_CLIENT_KEY
  export VAULT_ADDR
  VAULT_ADDR="$(vault_addr)"
}

# Run the vault CLI against the local instance. Refuses an inherited
# VAULT_TOKEN so a corporate token can never cross over.
vault_local() {
  vault_env_reset
  if [ -n "${VAULT_TOKEN:-}" ] && [ -z "${OSLS_ALLOW_VAULT_TOKEN:-}" ]; then
    fail "Refusing inherited VAULT_TOKEN. Unset it before using this stack."
  fi
  if [ -n "${LOCAL_VAULT_TOKEN:-}" ]; then
    VAULT_TOKEN="${LOCAL_VAULT_TOKEN}" HOME="${OSLS_VAULT_HOME}" \
      "${VAULT_BIN}" "$@"
  else
    HOME="${OSLS_VAULT_HOME}" VAULT_TOKEN="" "${VAULT_BIN}" "$@"
  fi
}

# Seal-status probes using vault's documented exit codes:
#   0 = unsealed, 2 = sealed, 1/other = error.
vault_is_running() { vault_local status >/dev/null 2>&1 || [ "$?" -eq 2 ]; }

vault_is_sealed() {
  vault_local status >/dev/null 2>&1
  case "$?" in
    0) return 1 ;;   # unsealed
    2) return 0 ;;   # sealed
    *) return 2 ;;   # cannot tell
  esac
}

vault_is_initialized() {
  local out
  out="$(vault_local status -format=json 2>/dev/null)" || {
    [ "$?" -eq 2 ] || return 1
  }
  printf '%s' "${out}" | grep -q '"initialized"[[:space:]]*:[[:space:]]*true'
}

port_is_listening() {
  local port="$1"
  if have lsof; then
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
  elif have ss; then
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}\$"
  elif have netstat; then
    netstat -an 2>/dev/null | grep -E 'LISTEN' | grep -Eq "[:.]${port}[[:space:]]"
  elif have python3; then
    python3 - "${port}" <<'PY'
import socket
import sys

with socket.socket() as sock:
    sock.settimeout(0.2)
    raise SystemExit(0 if sock.connect_ex(("127.0.0.1", int(sys.argv[1]))) == 0 else 1)
PY
  else
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Confirmation prompt requiring an exact typed word (e.g. REVOKE, RESTORE).
# ---------------------------------------------------------------------------
require_typed_confirmation() {
  local word="$1" prompt="${2:-Type ${1} to continue}" answer
  printf '%s: ' "${prompt}" >&2
  IFS= read -r answer || answer=""
  [ "${answer}" = "${word}" ] || fail "Confirmation did not match '${word}'. Aborting."
}

# Ensure a directory exists with owner-only permissions.
ensure_private_dir() {
  local d="$1"
  [ -d "${d}" ] || mkdir -p "${d}"
  chmod 700 "${d}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Hidden secret prompt. Reads one line of hidden input from the terminal and
# prints it on stdout so a caller can capture it with command substitution
# (which keeps the value in memory, never on a command line or in a file).
# Returns non-empty only if a value was entered. No `eval`, no globals.
#
#   pw="$(read_secret 'Admin password')"
# ---------------------------------------------------------------------------
read_secret() {
  local prompt="${1:-Secret}" value=""
  printf '%s: ' "${prompt}" >&2
  # `read -s` (hidden) is available in Bash 3.2.
  IFS= read -r -s value || value=""
  printf '\n' >&2
  printf '%s' "${value}"
}

# ---------------------------------------------------------------------------
# Admin password acquisition. Interactive (hidden prompt) by default. A
# strictly test-only noninteractive path exists ONLY when OSLS_E2E=1 is
# explicitly set in the environment (never true in a production run): the
# password is read once from a caller-supplied file, which MUST be a regular,
# non-symlink file with mode exactly 0600, and the file is deleted immediately
# after being read. This exists because driving a hidden password prompt
# through `expect` pattern-matching over a pty is unreliable in CI; it never
# changes production authentication, which always uses the hidden prompt.
# ---------------------------------------------------------------------------
read_admin_password() {
  local prompt="$1"
  if [ "${OSLS_E2E:-}" = "1" ]; then
    local f="${OSLS_E2E_ADMIN_PASSWORD_FILE:-}" mode value=""
    [ -n "${f}" ] || fail "OSLS_E2E=1 requires OSLS_E2E_ADMIN_PASSWORD_FILE to be set."
    [ -f "${f}" ] && [ ! -L "${f}" ] \
      || fail "OSLS_E2E_ADMIN_PASSWORD_FILE must be a regular, non-symlink file: ${f}"
    if mode="$(stat -c '%a' "${f}" 2>/dev/null)"; then
      :
    else
      mode="$(stat -f '%Lp' "${f}" 2>/dev/null)" \
        || fail "Unable to stat OSLS_E2E_ADMIN_PASSWORD_FILE: ${f}"
    fi
    [ "${mode}" = "600" ] \
      || fail "OSLS_E2E_ADMIN_PASSWORD_FILE must be mode 0600 (got ${mode}): ${f}"
    value="$(cat "${f}")"
    rm -f "${f}"
    printf '%s' "${value}"
    return 0
  fi
  read_secret "${prompt}"
}

# Create an owner-only temporary directory and print its path. Used for
# short-lived staging (backups, restore, session logs) that must never be
# world-readable.
make_secure_tmpdir() {
  local label="${1:-osls}" base d
  base="${TMPDIR:-/tmp}"
  d="$(mktemp -d "${base%/}/${label}.XXXXXX")" || fail "Unable to create a secure temporary directory."
  chmod 700 "${d}" 2>/dev/null || true
  printf '%s' "${d}"
}

# Validate that a file contains a single well-formed age public recipient
# (age1...). Never prints the file contents.
validate_age_recipient_file() {
  local f="$1"
  [ -r "${f}" ] || fail "age recipient file is not readable: ${f}"
  grep -Eq '^age1[0-9a-z]+$' "${f}" || fail "age recipient file is malformed (expected a single age1... line): ${f}"
}

# Return success only if the local Vault is running AND unsealed. Used by the
# scripts that must refuse to touch a sealed or absent Vault.
vault_require_unsealed() {
  vault_is_running || fail "Local Vault is not running on $(vault_addr). Start it with scripts/vault-start."
  if vault_is_sealed; then
    fail "Local Vault is sealed. Unseal it (or run scripts/work-session) first."
  fi
}
