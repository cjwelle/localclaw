# Contributing

Thanks for considering a contribution. This project is a **security baseline**,
so changes are held to the invariants below. Please read them before opening a
merge request.

LocalClaw is still in active development and is open for feedback. Bug reports,
documentation improvements, usability observations, and careful security
review are welcome through the GitHub repository. Please include your operating
system, the command or workflow you tested, and relevant sanitized output.

> **License:** this project is licensed under the **GNU General Public License
> v3.0 or later** (`GPL-3.0-or-later`); see [`../LICENSE`](../LICENSE). By
> contributing, you agree that your contributions are offered under the same
> license. Per project convention we do **not** add per-file copyright headers.

## Non-negotiable invariants

A change must not weaken any of these. If it needs to, that is a design
discussion first, not a merge request.

1. **Loopback only.** No component may listen on a non-loopback address. Do not
   enable a routable listener without TLS — and TLS + remote is out of scope for
   this project.
2. **No daemons or schedulers.** No launchd/systemd units, cron jobs, or timers.
   Sessions are foreground and operator-initiated.
3. **No messaging channels or remote control.** No inbound webhooks or bridges.
4. **Least privilege.** Keep the three-policy split (admin / agent / backup).
   New capabilities go in the narrowest policy that works.
5. **Secrets never touch the repo, disk (cleartext), logs, or the database.**
   Prompt for secrets; pass them through the environment for a single command;
   never as CLI arguments or files.
6. **Operator owns unseal/recovery/root material and the private age key.** The
   tooling must never view, store, or transmit them.
7. **User-owned directories.** Create config/state `700`, sensitive files `600`,
   write with `umask 077`.

## Before you commit — never add

- Real secrets, tokens, unseal shares, recovery keys, API keys, or private `age`
  identities (`*.agekey`, `*age-identity*`).
- Live databases (`*.sqlite`, `*.db`) or runtime state (Raft data, logs).
- Personal or organizational identifiers: names, emails, absolute home paths,
  tenant/company names, or internal hostnames. Use neutral placeholders.
- Rendered config (`stack.conf`, `vault.hcl`, `openclaw.json`, `secrets.map`) —
  only the `*.example` / `*.template` / `*.sample` sources are tracked.

`.gitignore` blocks the common cases as defense in depth, but review your diff.

## Style

- **Shell:** target Bash 3.2 (stock macOS). Avoid Bash 4-only features
  (associative arrays, `mapfile`, `${x^^}`). `set -euo pipefail` in executables;
  `pipefail` only in the sourced library. Keep helpers in `scripts/lib/common.sh`.
- **Diagnostics to stderr**, machine output to stdout.
- **Editor settings** come from `.editorconfig` (LF, final newline, 2-space
  indent; tabs in `Makefile`, 4 spaces in SQL).
- **Docs:** Markdown; use Mermaid for diagrams (see `ARCHITECTURE.md`). Keep the
  security posture accurate and internally consistent across files.

## Checks before opening a merge request

```sh
make doctor     # read-only preflight (safe anywhere)
make check      # shellcheck the scripts (install shellcheck first)
make test       # dependency-light suite against a throwaway HOME (never real HOME/creds)
```

For the full local CI mirror (including the Ubuntu-in-Docker run) use
`scripts/ci-local`; see [`CI-CD.md`](CI-CD.md). New behavior needs a test in
`tests/cases/`, and version changes go through `scripts/release`
([`VERSIONING.md`](VERSIONING.md)) — never hand-edit `VERSION` for a release.

Please also:

- Update `CHANGELOG.md` under **Unreleased**.
- Update the relevant `docs/` page if behavior or configuration changes.
- Keep `README.md`, `docs/`, config templates, and policies **mutually
  consistent** (mount names, ports, paths, retention counts).

## Commit / MR guidance

- Small, focused commits with clear messages (a Conventional Commits style like
  `feat(vault): …` / `docs: …` is welcome but not required).
- Describe the security impact of the change explicitly in the MR description.
- Note the OS(es) you tested on. The supported/tested OS matrix is a
  [maintainer decision](MAINTAINER-DECISIONS.md).

## Reporting security issues

Do **not** open a public issue for a vulnerability. Follow
[`../SECURITY.md`](../SECURITY.md).
