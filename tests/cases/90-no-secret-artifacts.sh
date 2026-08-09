# shellcheck shell=bash
# 90-no-secret-artifacts - the repository tracks no secrets, state, or rendered config.
#
# Defense in depth alongside the CI secret-scan job. We assert the working tree
# contains no forbidden artifact files (encrypted backups, live databases, key
# material, rendered runtime config, logs) and that no high-signal secret
# material is present in any tracked source. The tests/ directory is excluded
# from the CONTENT scan because this very file names the patterns it looks for.
. "${LIB_SH}"

# --- Forbidden artifact FILENAMES anywhere in the repo ----------------------
forbidden_names="
*.age
*.tar.gz.age
*.tar.age
*.sqlite
*.sqlite-wal
*.sqlite-shm
*.db
work_memory*
*.agekey
*age-identity*
*.key
*.pem
*.p12
*.pfx
*.recovery-keys
root-token*
"
bad=0
for pat in ${forbidden_names}; do
  found="$(find "${REPO_DIR}" -not -path '*/.git/*' -type f -name "${pat}" -print 2>/dev/null)"
  if [ -n "${found}" ]; then
    bad=1
    t_fail "forbidden artifact present (${pat}): ${found}"
  fi
done
[ "${bad}" -eq 0 ] && t_pass "no forbidden artifact filenames tracked"

# --- Rendered runtime config must NOT be present (only *.example/.template) ---
for rel in config/stack.conf config/vault.hcl config/openclaw.json config/secrets.map; do
  assert_absent "no rendered ${rel} in repo" "${REPO_DIR}/${rel}"
done
# No template backups.
baks="$(find "${REPO_DIR}/config" -maxdepth 1 -name '*.bak.*' -print 2>/dev/null)"
assert_eq "no config/*.bak.* in repo" "${baks}" ""

# --- The tracked *.example/.template/.sample sources DO exist ----------------
for rel in config/stack.conf.example config/vault.hcl.template \
           config/openclaw.json.example config/secrets.map.sample; do
  assert_file "tracked source present: ${rel}" "${REPO_DIR}/${rel}"
done

# --- High-signal secret CONTENT must not appear (excluding tests/) -----------
# The AGE pattern requires real key characters after the '-1' marker so the
# pattern text itself (which appears in the CI config and this file) is not a
# self-match.
content_hits="$(find "${REPO_DIR}" -type f \
  -not -path '*/.git/*' -not -path "${REPO_DIR}/tests/*" \
  -exec grep -lE 'AGE-SECRET-KEY-1[A-Z0-9]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|hvs\.[A-Za-z0-9]{8,}' {} + 2>/dev/null)"
if [ -n "${content_hits}" ]; then
  t_fail "secret-shaped content found in: ${content_hits}"
else
  t_pass "no secret-shaped content in tracked sources"
fi

# --- .gitignore blocks the common cases -------------------------------------
gi="${REPO_DIR}/.gitignore"
for rule in '*.age' '*.sqlite' '/config/stack.conf' 'vault-backup-age-recipient'; do
  if grep -qF "${rule}" "${gi}"; then t_pass ".gitignore blocks ${rule}"
  else t_fail ".gitignore is missing a rule for ${rule}"; fi
done

t_summary
