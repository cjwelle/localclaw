# Maintainer Decisions Checklist

This foundation release intentionally leaves a few project-level choices open.
Work through this checklist before publishing the repository or cutting a `1.0`.
Each item lists what to decide, where it is referenced, and how to record it.

## 1. License — RESOLVED

- [x] **Resolved:** **GNU General Public License v3.0 or later**
  (`SPDX-License-Identifier: GPL-3.0-or-later`).
- **What was done:** added the canonical GPLv3 text as `LICENSE`, a License
  section in `README.md`, and updated the `docs/CONTRIBUTING.md` note so outside
  contributions are understood to be offered under the same terms. Per project
  convention, **no per-file copyright headers** are added.
- **Where referenced:** `LICENSE`, `README.md` (License section),
  `docs/CONTRIBUTING.md`, `CHANGELOG.md`.

## 2. Namespace / project location

- [ ] Decide whether the project needs an organization namespace and record the
  canonical project slug.
- **Why it matters:** links and clone instructions depend on it.
- **Where referenced:** `SECURITY.md`, `CHANGELOG.md` link refs (`about:blank`
  placeholders).
- **Record by:** updating the changelog compare links and any placeholder
  namespace strings.

## 3. Support policy — RESOLVED

- [x] **Resolved.** Security support tracks **published release lines** only; a
  line is listed as supported once it is actually released. At `0.1.0`, the
  `0.1.x` line is supported and earlier/unreleased versions are not. Future lines
  (illustrated by `1.5.x`, `2.0.x`, `2.5.x`) are added to the table only when
  released. Initial acknowledgement of a report is expected **within 1–2 weeks**.
- **What was done:** filled in the Supported-versions table and the Response
  expectations in `SECURITY.md`; summarized the same in `docs/SECURITY.md`; added
  `docs/VERSIONING.md` (SemVer, `VERSION` canonical, tag gating) and
  `docs/CI-CD.md` (release only after lint/security/Ubuntu/macOS pass).
- **Where referenced:** `SECURITY.md`, `docs/SECURITY.md`, `docs/VERSIONING.md`,
  `README.md` (Security & support), `CHANGELOG.md`.
- **Resolved separately:** the security *contact* channel (item 6) — a support
  policy is not a contact address.

## 4. Tested OS versions

- [x] **Resolved for the current macOS host:** macOS `15.7.7` is the validated
  native host used for the latest docs and installer checks.
- **Why it matters:** the scripts target Bash 3.2 and POSIX-ish tooling, but the
  Vault/age/apt specifics vary by release.
- **Where referenced:** `README.md` (Supported platforms),
  `docs/QuickStartInstall.md`.
- **Record by:** updating the supported-platform notes when new OS releases are
  validated.

## 5. Version / compatibility matrix

- [x] **Resolved for the current matrix:** the README now lists the validated
  versions and supported baselines for the core external tools.
  Pin the supported (or minimum) versions of the external tools:
  `vault`, `openclaw`, `age`, `sqlite3`, Bash.
- **Why it matters:** Vault storage/API and OpenClaw's config schema can change
  between releases; the minimal `openclaw.json` is deliberately non-authoritative.
- **Where referenced:** `README.md` (Prerequisites), `docs/QuickStartInstall.md`,
  `config/openclaw.json.example` (schema caveat).
- **Record by:** extending the compatibility matrix (tool → tested/min version)
  in the README or Quick Start Install doc, and bumping `VERSION` per SemVer when it changes.

  | Tool | Tested version | Minimum |
  | --- | --- | --- |
  | vault | 2.0.3 | Published supported release line |
  | openclaw | 2026.7.1-2 | `extended-stable` channel |
  | age | package-manager provided | Required for backups |
  | sqlite3 | 3.43.2 | Working CLI on the supported OSes |
  | bash | 3.2.57 | 3.2 |

## 6. Security contact — RESOLVED

- [x] **Resolved:** the project maintainer and security contact is
  **Christopher Welle** (cjwelle@gmail.com), alongside the
  repository host's private advisory workflow.
- **What was done:** replaced the placeholder in `SECURITY.md` with the real
  maintainer and security contact; recorded the same contact in `docs/SECURITY.md`
  and `README.md`. `docs/CONTRIBUTING.md` continues to defer to `SECURITY.md`.
- **Where referenced:** `SECURITY.md`, `docs/SECURITY.md`, `README.md`,
  `docs/CONTRIBUTING.md`.

---

### Definition of done for publishing

- [x] `LICENSE` added — GNU GPL v3.0 or later (`GPL-3.0-or-later`).
- [ ] Namespace, links, and placeholders resolved.
- [x] Support policy and response expectations written (`SECURITY.md`).
- [ ] Tested OS versions listed.
- [x] Tool version/compatibility matrix filled in.
- [x] Real security contact in `SECURITY.md`.
- [ ] `make doctor` and `make check` pass on each tested OS.
- [ ] A final scan confirms **no** secrets, personal names, emails, absolute home
  paths, tokens, keys, live databases, or runtime state are tracked.
