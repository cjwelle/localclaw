#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/localclaw-e2e.XXXXXX")"
trap 'rc=$?; if [ "$rc" -ne 0 ] && [ "${LOCALCLAW_E2E_KEEP:-}" = 1 ]; then echo "E2E temp retained: $T" >&2; else rm -rf "$T" 2>/dev/null || true; fi; exit "$rc"' EXIT INT TERM
for b in bash python3 expect vault jq; do command -v "$b" >/dev/null 2>&1 || { echo "SKIP: missing $b" >&2; exit 0; }; done
if [ -n "${LOCALCLAW_E2E_PORT_BASE:-}" ]; then
  VPORT="${LOCALCLAW_E2E_PORT_BASE}"
  CPORT="$((VPORT + 10))"
  GPORT="$((VPORT + 2))"
else
  read -r VPORT CPORT GPORT <<EOF
$(python3 - <<'PY'
import socket
ports = []
for _ in range(3):
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    ports.append(str(s.getsockname()[1]))
    s.close()
print(*ports)
PY
)
EOF
fi
H="$T/home"; B="$T/bin"; mkdir -p "$H" "$B"
cat >"$B/vault-e2e" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
v="${LOCALCLAW_E2E_REAL_VAULT:-vault}"; a="http://127.0.0.1:${LOCALCLAW_E2E_VAULT_PORT}"
if [ "${1:-}" = server ]; then
  "$v" server -dev -dev-root-token-id=e2e-root -dev-listen-address="127.0.0.1:${LOCALCLAW_E2E_VAULT_PORT}" >"${LOCALCLAW_E2E_VAULT_LOG}" 2>&1 & p=$!
  trap 'kill "$p" 2>/dev/null || true; wait "$p" 2>/dev/null || true' EXIT INT TERM
  for i in $(seq 1 80); do VAULT_ADDR="$a" VAULT_TOKEN=e2e-root "$v" status >/dev/null 2>&1 && break; sleep .1; done
  VAULT_ADDR="$a" VAULT_TOKEN=e2e-root "$v" secrets enable -path=local kv-v2 >/dev/null 2>&1 || true
  VAULT_ADDR="$a" VAULT_TOKEN=e2e-root "$v" policy write admin - >/dev/null <<'P'
path "local/data/*" { capabilities = ["read"] }
path "local/metadata/*" { capabilities = ["read", "list"] }
path "auth/token/create" { capabilities = ["update", "sudo"] }
path "auth/token/create/*" { capabilities = ["update", "sudo"] }
P
  VAULT_ADDR="$a" VAULT_TOKEN=e2e-root "$v" policy write agent - >/dev/null <<'P'
path "local/data/test/*" { capabilities = ["read"] }
path "local/metadata/test/*" { capabilities = ["read", "list"] }
path "auth/token/revoke-self" { capabilities = ["update"] }
P
  VAULT_ADDR="$a" VAULT_TOKEN=e2e-root "$v" policy write backup - >/dev/null <<'P'
path "sys/storage/raft/snapshot" { capabilities = ["read"] }
path "auth/token/revoke-self" { capabilities = ["update"] }
P
  VAULT_ADDR="$a" VAULT_TOKEN=e2e-root "$v" auth enable userpass >/dev/null 2>&1 || true
  VAULT_ADDR="$a" VAULT_TOKEN=e2e-root "$v" write auth/userpass/users/e2e-admin password=e2e-admin-pass policies=admin >/dev/null
  VAULT_ADDR="$a" VAULT_TOKEN=e2e-root "$v" write auth/token/roles/agent-session allowed_policies=agent orphan=true renewable=false token_ttl=8h token_max_ttl=8h >/dev/null
  VAULT_ADDR="$a" VAULT_TOKEN=e2e-root "$v" write auth/token/roles/backup-session allowed_policies=backup orphan=true renewable=false token_ttl=8h token_max_ttl=8h >/dev/null
  VAULT_ADDR="$a" VAULT_TOKEN=e2e-root "$v" kv put local/test/credential api_key="${LOCALCLAW_E2E_EXPECTED_API_KEY:-e2e-secret-value}" >/dev/null
  printf '%s' e2e-admin-pass | VAULT_ADDR="$a" VAULT_TOKEN='' HOME="${LOCALCLAW_E2E_CLIENT_HOME:-/tmp}" "$0" login -method=userpass -no-store -format=json username=e2e-admin password=- >/dev/null || { echo 'E2E admin setup self-test failed' >&2; exit 1; }
  : >"${LOCALCLAW_E2E_VAULT_READY_FILE}"
  wait "$p"
else VAULT_ADDR="$a" HOME="${LOCALCLAW_E2E_CLIENT_HOME:-/tmp}" exec "$v" "$@"; fi
EOF
chmod 700 "$B/vault-e2e"
cat >"$B/openclaw-e2e" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  *" gateway run "*)
    [ "${TEST_API_KEY:-}" = "${LOCALCLAW_E2E_EXPECTED_API_KEY:-e2e-secret-value}" ] || exit 1
    echo gateway-secret-injection=pass >"$LOCALCLAW_E2E_MARKER"
    exec python3 - "$LOCALCLAW_E2E_OPENCLAW_PORT" <<'P'
import sys
from http.server import BaseHTTPRequestHandler,HTTPServer
class H(BaseHTTPRequestHandler):
 def do_GET(self): self.send_response(200); self.end_headers(); self.wfile.write(b'ok')
 def log_message(self,*x): pass
HTTPServer(('127.0.0.1',int(sys.argv[1])),H).serve_forever()
P
    ;;
  *" tui"*) IFS= read -r _ || true ;;
  *) exit 2 ;;
esac
EOF
chmod 700 "$B/openclaw-e2e"
export HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.state" LOCALCLAW_E2E_CLIENT_HOME="$T/vault-client-home"
mkdir -p "$LOCALCLAW_E2E_CLIENT_HOME"
export LOCALCLAW_E2E_VAULT_PORT="$VPORT" LOCALCLAW_E2E_OPENCLAW_PORT="$GPORT" LOCALCLAW_E2E_VAULT_LOG="$T/vault.log" LOCALCLAW_E2E_MARKER="$T/marker" LOCALCLAW_E2E_REAL_VAULT="$(command -v vault)" LOCALCLAW_E2E_VAULT_READY_FILE="$T/vault-ready"
bash "$ROOT/scripts/bootstrap" >/dev/null
cat >"$H/.config/localclaw/stack.conf" <<EOF
VAULT_PORT=$VPORT
VAULT_CLUSTER_PORT=$CPORT
VAULT_ADMIN_USER=e2e-admin
VAULT_BIN=$B/vault-e2e
OPENCLAW_BIN=$B/openclaw-e2e
OPENCLAW_PORT=$GPORT
EOF
printf '%s\n' 'TEST_API_KEY test/credential api_key' >"$H/.config/localclaw/secrets.map"
bash "$ROOT/scripts/bootstrap" >/dev/null
# Test-only noninteractive admin password injection (see read_admin_password
# in scripts/lib/common.sh). Driving a hidden password prompt through expect
# pattern-matching over a pty is unreliable in CI, so the password is instead
# supplied via a private 0600 file that work-session reads and deletes; this
# never touches production authentication, which still uses a hidden prompt.
ADMIN_PW_FILE="$T/admin-pw"
(umask 077; printf '%s\n' e2e-admin-pass >"$ADMIN_PW_FILE")
chmod 600 "$ADMIN_PW_FILE"
LOCALCLAW_E2E_ROOT="$ROOT" LOCALCLAW_E2E=1 LOCALCLAW_E2E_ADMIN_PASSWORD_FILE="$ADMIN_PW_FILE" expect <<'P'
set timeout 90
log_user 1
spawn $env(LOCALCLAW_E2E_ROOT)/scripts/work-session
expect {
  -re {Opening the OpenClaw terminal UI} { send -- "\004"; exp_continue }
  eof {}
  timeout { exit 1 }
}
catch wait result
if {[lindex $result 3] != 0} { exit [lindex $result 3] }
P
[ -e "$ADMIN_PW_FILE" ] && { echo "admin password file was not consumed" >&2; exit 1; }
[ -f "$T/marker" ] && [ "$(cat "$T/marker")" = gateway-secret-injection=pass ] || exit 1
python3 - "$VPORT" "$GPORT" <<'P'
import socket,sys
for value in sys.argv[1:]:
    with socket.socket() as s:
        s.settimeout(.2)
        if s.connect_ex(("127.0.0.1", int(value))) == 0:
            raise SystemExit(f"test port remained open: {value}")
P
echo 'E2E PASS: lifecycle, Vault injection, gateway, cleanup'
