# shellcheck shell=bash
# 70-config-validation - shipped templates/policies are internally consistent.
#
# Static checks (no Vault, no secrets): every stack.conf.example key is honored
# by the parser; every template placeholder is one bootstrap actually supplies;
# secrets.map.sample lines are well-formed; policies exist and match the default
# mount name; and the ports/mount agree across the sample and the library.
. "${LIB_SH}"

CFG="${REPO_DIR}/config"

# --- stack.conf.example: all keys are in the parser allow-list ---------------
# Loading the sample must emit no "Ignoring unknown stack.conf key" warning.
warns="$( ( . "${COMMON_SH}"; load_stack_config "${CFG}/stack.conf.example" ) 2>&1 1>/dev/null )"
if printf '%s' "${warns}" | grep -q 'Ignoring unknown stack.conf key'; then
  t_fail "stack.conf.example has keys the parser rejects: ${warns}"
else
  t_pass "every stack.conf.example key is honored by load_stack_config"
fi

# --- vault.hcl.template placeholders are all supplied by bootstrap -----------
# bootstrap renders vault.hcl with exactly these keys.
vault_known="VAULT_HOST VAULT_PORT VAULT_CLUSTER_PORT VAULT_NODE_ID VAULT_DATA_DIR"
missing=""
for tok in $(grep -Eo '@[A-Z][A-Z0-9_]*@' "${CFG}/vault.hcl.template" | sort -u); do
  name="${tok#@}"; name="${name%@}"
  case " ${vault_known} " in *" ${name} "*) : ;; *) missing="${missing} ${name}" ;; esac
done
assert_eq "vault.hcl.template uses only known placeholders" "${missing}" ""

# --- openclaw.json.example placeholders are all supplied by bootstrap --------
oc_known="OPENCLAW_PORT WORKSPACE_DIR"
missing=""
for tok in $(grep -Eo '@[A-Z][A-Z0-9_]*@' "${CFG}/openclaw.json.example" | sort -u); do
  name="${tok#@}"; name="${name%@}"
  case " ${oc_known} " in *" ${name} "*) : ;; *) missing="${missing} ${name}" ;; esac
done
assert_eq "openclaw.json.example uses only known placeholders" "${missing}" ""

# The restricted config loader must never execute shell content from values.
injection_marker="${HOME}/config-injection-marker"
malicious_conf="${HOME}/malicious-stack.conf"
inert_value='$(touch '"${injection_marker}"')'
printf 'VAULT_NODE_ID=%s\n' "${inert_value}" >"${malicious_conf}"
assert_ok "config parser accepts value as inert text" bash -c \
  '. "$1"; load_stack_config "$2"; test "$VAULT_NODE_ID" = "$3"' \
  _ "${COMMON_SH}" "${malicious_conf}" "${inert_value}"
assert_absent "config parser did not execute command substitution" "${injection_marker}"

# --- secrets.map.sample: every active line is 'ENV path field' ---------------
bad=0
while IFS= read -r line || [ -n "${line}" ]; do
  case "${line}" in ''|'#'*) continue ;; esac
  IFS=' ' read -r env_name kv_path kv_field extra <<EOF
${line}
EOF
  if [ -z "${env_name}" ] || [ -z "${kv_path}" ] || [ -z "${kv_field}" ] || [ -n "${extra}" ]; then
    bad=1
    continue
  fi
  printf '%s' "${env_name}" | grep -Eq '^[A-Z_][A-Z0-9_]*$' || bad=1
done < "${CFG}/secrets.map.sample"
assert_eq "secrets.map.sample lines are well-formed (ENV path field)" "${bad}" "0"

# --- Policies exist, are non-empty, and reference the default mount ----------
for p in admin agent backup; do
  f="${REPO_DIR}/policies/${p}.hcl"
  if [ -s "${f}" ]; then t_pass "policy present and non-empty: ${p}.hcl"
  else t_fail "policy missing/empty: ${p}.hcl"; fi
done
# agent/admin policies address the 'local/' KV mount (the VAULT_KV_MOUNT default).
assert_ok "agent policy references the 'local/' mount" \
  grep -q 'local/' "${REPO_DIR}/policies/agent.hcl"
assert_ok "agent role is orphaned from temporary admin login" \
  grep -q 'orphan=true renewable=true' "${REPO_DIR}/scripts/vault-bootstrap"
assert_ok "backup role is orphaned from temporary admin login" \
  grep -q 'orphan=true renewable=false' "${REPO_DIR}/scripts/vault-bootstrap"

# --- Ports/mount agree between the sample and the library defaults ------------
grep -q '^VAULT_PORT=18200'   "${CFG}/stack.conf.example" && t_pass "sample VAULT_PORT=18200" || t_fail "sample VAULT_PORT mismatch"
grep -q '^OPENCLAW_PORT=18789' "${CFG}/stack.conf.example" && t_pass "sample OPENCLAW_PORT=18789" || t_fail "sample OPENCLAW_PORT mismatch"
grep -q '^VAULT_KV_MOUNT=local' "${CFG}/stack.conf.example" && t_pass "sample VAULT_KV_MOUNT=local" || t_fail "sample mount mismatch"
grep -q 'VAULT_PORT="18200"'   "${COMMON_SH}" && t_pass "library default VAULT_PORT=18200" || t_fail "library VAULT_PORT default mismatch"
grep -q 'OPENCLAW_PORT="18789"' "${COMMON_SH}" && t_pass "library default OPENCLAW_PORT=18789" || t_fail "library OPENCLAW_PORT default mismatch"

# --- VERSION is present and semver-shaped ------------------------------------
ver="$(cat "${REPO_DIR}/VERSION" 2>/dev/null | tr -d '[:space:]')"
if printf '%s' "${ver}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  t_pass "VERSION is a bare semver: ${ver}"
else
  t_fail "VERSION is not a bare X.Y.Z semver: '${ver}'"
fi

t_summary
