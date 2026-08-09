# shellcheck shell=bash
# 80-docs-links - every relative Markdown link in README/docs resolves to a file.
#
# Broken internal links are a common documentation regression. We scan README.md
# and docs/*.md for `](target)` links, ignore external (http/mailto) and pure
# anchor links, strip any `#anchor` suffix, resolve the path relative to the
# file, and assert the target exists. CHANGELOG's intentional `about:blank`
# placeholders are out of scope here.
. "${LIB_SH}"

files="${REPO_DIR}/README.md"
for f in "${REPO_DIR}"/docs/*.md; do
  [ -e "${f}" ] || continue
  files="${files} ${f}"
done

missing=0
checked=0
for f in ${files}; do
  [ -r "${f}" ] || continue
  dir="$(dirname "${f}")"
  links="$(grep -Eo '\]\([^)]+\)' "${f}" 2>/dev/null | sed 's/^](//; s/)$//')"
  for link in ${links}; do
    case "${link}" in
      http://*|https://*|mailto:*|'#'*) continue ;;
    esac
    target="${link%%#*}"          # drop any '#anchor'
    [ -n "${target}" ] || continue
    case "${target}" in
      /*) path="${target}" ;;
      *)  path="${dir}/${target}" ;;
    esac
    checked=$((checked + 1))
    if [ ! -e "${path}" ]; then
      missing=$((missing + 1))
      t_fail "broken link in $(basename "${f}"): ${link}"
    fi
  done
done

assert_ne "at least some links were checked" "${checked}" "0"
assert_eq "no broken internal Markdown links" "${missing}" "0"

# The core docs the README advertises must exist.
for d in INSTALL CONFIGURATION SECURITY BACKUP-RESTORE OPERATIONS ARCHITECTURE \
         CONTRIBUTING MAINTAINER-DECISIONS CI-CD VERSIONING; do
  assert_file "docs/${d}.md exists" "${REPO_DIR}/docs/${d}.md"
done

t_summary
