# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Render a schema-valid OpenClaw local-mode config and explicitly wire its
  config, state, and workspace paths into both the foreground gateway and TUI.
- Keep session tokens independent of the short-lived administrator parent,
  revoke the administrator login before gateway startup, and correctly validate
  provider-secret names, paths, and newline-free values.
- Install OpenClaw's official `extended-stable` npm package during the explicit
  `scripts/install --apply` workflow instead of leaving that step manual.

### Added
- `scripts/install` — guided, no-op-by-default installer for prerequisites
  (Homebrew on macOS; apt on Ubuntu/Debian). Plans by default and prints the
  exact commands; installs only under `--apply` with a typed `INSTALL`
  confirmation and never pipes a download into a shell. Covers vault, sqlite3,
  age, jq, git, curl, tmux, tar, node/npm, optional shellcheck, and OpenClaw's
  official `extended-stable` npm package.
- `scripts/bootstrap` — idempotent renderer: creates owner-only XDG
  config/state/workspace directories (`umask 077`, `700`/`600`), seeds
  `stack.conf`/`secrets.map` from the samples only if absent, renders
  `vault.hcl`/`openclaw.json` (preserving any changed copy as a timestamped
  `.bak`), initializes the SQLite work-memory DB from `sql/schema.sql`, and
  copies missing workspace-template files. Creates no secrets. Supports
  `--dry-run`.
- `scripts/vault-bootstrap` — operator-driven Vault setup with subcommands:
  `init` (guidance only — you run `operator init`/`unseal`; the tool never sees
  your shares or root token), `configure` (KV v2 mount, admin/agent/backup
  policies, `userpass` admin user via hidden password read on stdin, and the
  `agent-session`/`backup-session` token roles; idempotent, `--dry-run`),
  `revoke-root` (typed `REVOKE` confirmation, never persists the token), and a
  read-only `status`. No root token, unseal share, or password is ever written
  to disk.
- `Makefile` targets `install`, `bootstrap`, and `vault-bootstrap`; `make
  check` now lints all shipped scripts.
- `LICENSE` — the project is now licensed under the **GNU General Public License
  v3.0 or later** (`SPDX-License-Identifier: GPL-3.0-or-later`). Added the
  canonical GPLv3 text, a License section in `README.md`, and license notices in
  `docs/CONTRIBUTING.md`; resolved the license item in
  `docs/MAINTAINER-DECISIONS.md`. No per-file copyright headers are used.
- Prominent official OpenClaw references in `README.md` and `docs/QUICKSTARTINSTALLATION.md`
  (<https://openclaw.ai/>, <https://docs.openclaw.ai/install>, and the official
  installer <https://openclaw.ai/install.sh>), while keeping the project rule to
  review any downloaded installer and never curl-pipe it into a shell.
- `scripts/work-session` — foreground session launcher (Bash 3.2 safe). Refuses
  an inherited `VAULT_TOKEN` and conflicting listeners; owns the local Vault and
  the loopback OpenClaw gateway as children; prompts (hidden) for unseal shares
  and the admin password (read on stdin, never argv); mints dedicated
  least-privilege `agent-session` and `backup-session` tokens via the Vault
  roles; injects **only** the agent token and the mapped provider keys into the
  foreground gateway; opens the TUI/chat (no daemon or messaging surface); and on
  a clean exit runs guarded cleanup — encrypted backup (while Vault is still up),
  token revocation, Vault shutdown, temp-log removal. `--dry-run` validates
  without starting anything; `--force-backup` forces a same-day exit backup. A
  forced kill (`kill -9`) or power loss bypasses cleanup and the exit-time backup.
- `scripts/backup` — consistent, `age`-encrypted Vault Raft snapshot backup
  (Bash 3.2 safe). Stages in an owner-only temp dir; packages the snapshot with
  the non-secret config and policies plus a `MANIFEST.txt` and `SHA256SUMS`;
  streams `tar | age -R <recipient-file>` so **no plaintext archive is ever
  written**; optionally verifies decryption with `BACKUP_VERIFY_IDENTITY`;
  writes atomic `Daily/` and `Weekly/` archives to the validated `BACKUP_DIR`;
  and enforces 14-daily / 8-weekly retention (from `stack.conf`). Refuses unsafe
  destinations and never packages live Raft data, credentials, the private age
  identity, or runtime logs. Supports `--force` and a Vault-free `--dry-run`.
- `Makefile` targets `work-session` and `backup`; `make check` now also lints
  both new scripts.
- `scripts/restore` — recovery/inspection for age-encrypted Vault backups (Bash
  3.2 safe). **Read-only by default:** validates the archive + identity paths,
  decrypts into an owner-only temp dir (age reads the identity from a **file**,
  never argv), **path-safety checks the tar before extraction** (refuses absolute
  paths, `..`, and any non-regular-file member such as symlinks/hardlinks/device
  nodes), verifies `MANIFEST.txt` and every `SHA256SUMS` checksum, and runs
  `operator raft snapshot inspect`. Provides staged recovery (`--stage-to`) and
  an explicit opt-in live-config restore (`--restore-config`) with timestamped
  conflict backups; never overwrites live config/workspace automatically. The
  destructive `operator raft snapshot restore` runs only under `--restore` after
  an exact typed `restore vault snapshot` confirmation against a running, unsealed
  local Vault; `-force` is not used by default and is gated behind `--force` plus
  a second `force overwrite` confirmation (documented for new/empty clusters).
- `scripts/uninstall` — safe removal of the stack's **generated** config/tool
  files (Bash 3.2 safe). **Plan-only by default;** `--apply` requires a typed
  `UNINSTALL` confirmation. Refuses unsafe roots (must be an absolute,
  `..`-free, app-owned path — never a system/home dir). Preserves Vault Raft
  data, the SQLite work-memory DB, the runtime home, your **workspace**, and your
  **backup directory** by default. `--purge-data` (separate flag + second
  `DELETE DATA` confirmation) deletes local runtime state, and **refuses while a
  local Vault is listening** — it never stops a process it did not start. Never
  removes package managers or shared dependencies.
- `Makefile` targets `restore` and `uninstall`; `make check` now also lints
  both new scripts.
- **Test-suite** (`tests/run.sh`, `tests/lib.sh`, `tests/cases/`) — a
  dependency-light, Bash-3.2-safe suite that runs every case against a
  **throwaway sandbox `HOME`** and refuses to run without a private temp dir; it
  never uses the real `HOME`, real credentials, a real Vault, or the network, and
  cases `skip` gracefully when an optional tool (`age`/`sqlite3`/`jq`) is absent.
  Covers: `bash -n` syntax + executable bits; plan/dry-run safety (nothing
  created); bootstrap rendering, permissions, and byte-for-byte idempotency;
  `validate_safe_dir`/`validate_backup_dir` unsafe-path refusal; synthetic
  `prune_to_count` retention; restore traversal/symlink/checksum/MANIFEST/identity
  defenses (real `age`-encrypted fixtures); uninstall preservation vs
  `--purge-data`; config/template/policy/port consistency; docs internal-link
  resolution; a no-secret/no-runtime-artifact scan; and `scripts/release` SemVer
  + tag gating.
- **`docker/Dockerfile.ci`** — an `ubuntu:latest` test image that installs only
  the suite's tools, runs as a **non-root** user, starts no services, and COPYs
  nothing in (the repo is bind-mounted). Linux only by design; there is no macOS
  image and none is faked.
- **`scripts/ci-local`** — run the CI checks locally. `native` runs the suite on
  the current host (macOS or Linux) plus shellcheck; `pull`/`build`/`ubuntu`/`all`
  drive the Ubuntu image **explicitly** (no implicit Docker/network use). The
  `ubuntu` run mounts the repo **read-only** with `--network none`.
- **`scripts/release`** — SemVer version helper. `current`/`verify`/`prepare`.
  `verify` validates the `VERSION` format and, on a tag build, requires
  `CI_COMMIT_TAG == v<VERSION>` exactly. `prepare <version>` edits `VERSION` and
  rolls the CHANGELOG `Unreleased` heading into the new version — and **never
  runs git** (no commit/tag/push) and never auto-increments. `LOCALCLAW_RELEASE_ROOT`
  lets the tests exercise `prepare` against a throwaway copy.
- **`.gitlab-ci.yml`** — internal-friendly pipeline (free tier; no privileged
  containers, no `services:` daemons, no registry required): shellcheck lint,
  Ubuntu-latest tests, a self-contained secret scan (with an optional, **pinned**
  `zricethezav/gitleaks:v8.18.4` job, off by default), version verification,
  packaging (versioned tarball + `SHA256SUMS`), a **native macOS** job on a
  runner tagged `macos`, and a **tag-only** release job that publishes artifacts
  + checksums only after lint/security/Ubuntu/macOS/version pass.
- **`docs/CI-CD.md`** and **`docs/VERSIONING.md`** — the pipeline/local-CI guide
  (including why macOS is tested natively, not in a container) and the SemVer /
  release-flow policy (`VERSION` canonical, tag-gated releases).
- `Makefile` targets `test`, `ci-local`, `version-verify`, and `release`
  (`make release V=X.Y.Z`); `make check` now also lints `scripts/ci-local` and
  `scripts/release`.
- Security **support policy** defined in `SECURITY.md` (and summarized in
  `docs/SECURITY.md`): support tracks **published release lines** — `0.1.x` is
  supported at `0.1.0`; earlier/unreleased lines are not, and illustrative future
  lines (`1.5.x`/`2.0.x`/`2.5.x`) are listed only once released. Initial
  acknowledgement of a report is expected **within 1–2 weeks**. Resolves the
  support-policy item in `docs/MAINTAINER-DECISIONS.md`.

### Changed
- OpenClaw release policy: the stack now defaults to the **`extended-stable`**
  npm dist-tag / update channel for stability instead of the rolling `@latest`
  tag. `scripts/install` plans `npm install -g openclaw@extended-stable`, and the
  docs show `openclaw update --channel extended-stable`. The choice is a
  documented default that operators may override; see
  <https://docs.openclaw.ai/install/development-channels>.
- `scripts/vault-bootstrap` — the `backup-session` token role now issues an
  8h-max token (was 15m/30m). The exit-time backup token is minted at session
  start but used at session exit, so its TTL must span a full work session.

### Fixed
- `scripts/vault-start` is now marked executable so `work-session` can launch it.
- `scripts/bootstrap` — the work-memory DB init now discards `sqlite3` stdout so
  connection PRAGMAs (`journal_mode`/`busy_timeout`) no longer echo `wal`/`5000`
  into the bootstrap output.
- `config/vault.hcl.template` — removed a literal `@PLACEHOLDERS@` token from a
  comment that tripped the renderer's unresolved-placeholder guard and made
  `scripts/bootstrap` fail.
- `render_template` (in `scripts/lib/common.sh`) now skips the rewrite and the
  `.bak` backup when the rendered content is byte-identical to the existing
  file, so re-running `bootstrap` no longer accumulates backups.

### Planned
- `scripts/rebuild-laptop` — operator-approved, manual disaster recovery for a
  fresh machine: install prerequisites, authenticate to cloud-sync/secret
  manager interactively, stand up an isolated empty Vault, then hand off to
  `scripts/restore --restore --force` (new-cluster restore). Documented in
  `docs/BACKUP-RESTORE.md`.

## [0.1.0] - 2026-08-09

Foundation release. Documentation, configuration templates, policies, schema,
and workspace templates only — no services are started and nothing is
installed.

### Added
- Project documentation: `README.md`; `docs/QUICKSTARTINSTALLATION.md`,
  `docs/CONFIGURATION.md`, `docs/SECURITY.md`, `docs/BACKUP-RESTORE.md`,
  `docs/OPERATIONS.md`, `docs/CONTRIBUTING.md`, `docs/ARCHITECTURE.md`
  (with Mermaid diagrams), and `docs/MAINTAINER-DECISIONS.md`.
- Configuration templates: `config/stack.conf.example`,
  `config/vault.hcl.template`, `config/openclaw.json.example`,
  `config/secrets.map.sample`.
- Vault policies: `policies/admin.hcl`, `policies/agent.hcl`,
  `policies/backup.hcl`.
- Work-memory SQL: `sql/schema.sql`, `sql/purge_expired.sql`, `sql/README.md`.
- Workspace templates: `workspace-template/{AGENTS,SOUL,USER,IDENTITY,TOOLS,HEARTBEAT}.md`
  and an empty `workspace-template/memory/` directory.
- Shipped scripts: `scripts/doctor` (read-only preflight),
  `scripts/vault-start` (foreground, loopback-only Vault), and the shared
  `scripts/lib/common.sh` library.
- Repository meta: `.gitignore`, `.editorconfig`, `Makefile`, `VERSION`,
  `SECURITY.md`, this changelog.

### Security
- Loopback-only listeners, no daemons or schedulers by default, least-privilege
  Vault policies, owner-only directories, secret prompts only, and a private
  age identity that never lives in the repository. See `docs/SECURITY.md`.

[Unreleased]: about:blank
[0.1.0]: about:blank
