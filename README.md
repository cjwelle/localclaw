# LocalClaw

Canonical repositories:

- GitHub: <https://github.com/cjwelle/localclaw>

The `website/` directory contains the landing page deployed to
<https://localclaw.bot>.

Bootstrap a **secure, local-only OpenClaw workstation** — a single-operator AI
coding/ops assistant that keeps its secrets in a local [HashiCorp Vault][vault],
records concise operational memory in [SQLite][sqlite], runs the gateway in the
**foreground only**, and can take **optional [age][age]-encrypted backups** of
its Vault snapshot.

Everything binds to loopback. There are **no messaging channels, no daemons, and
no schedulers** by default. Secrets are prompted for at the moment of use and
are never written to the repository, workspace files, logs, or the memory
database.

> **OpenClaw is a separate upstream project.** This repository is an independent,
> opinionated hardening layer around it — not a fork or a redistribution. For
> OpenClaw itself, always defer to the official sources:
>
> - Project: <https://openclaw.ai/>
> - Install docs: <https://docs.openclaw.ai/install>
> - Release channels: <https://docs.openclaw.ai/install/development-channels>
> - Official installer script: <https://openclaw.ai/install.sh>
>
> Follow the upstream docs for the canonical package name and installation steps.
> This stack **defaults to the `extended-stable` release channel** for stability
> (`npm install -g openclaw@extended-stable`, or `openclaw update --channel
> extended-stable`) rather than the rolling `@latest` tag; the choice is a
> documented default you may override — see the release-channels link above.
> **Review any installer before running it** — download `install.sh`, read it,
> then run the reviewed copy. This project never curl-pipes a script into a
> shell, and neither should you.

> **Status: foundation (v0.1.0).** Use `./localclaw` as the unified install,
> update, doctor, backup, and credential-adapter entry point. This repository ships documentation,
> configuration templates, Vault policies, the SQL schema, workspace templates,
> and the scripts: `install`, `bootstrap`, `vault-bootstrap`, the read-only
> `doctor`, the foreground `vault-start`, the foreground session launcher
> `work-session`, the age-encrypted `backup`, the read-only-by-default `restore`,
> and the plan-by-default `uninstall`. A full new-machine
> `rebuild-laptop` remains manual by design (see
> [`docs/BACKUP-RESTORE.md`](docs/BACKUP-RESTORE.md) and
> [CHANGELOG.md](CHANGELOG.md)). Running these scripts still **does not** install
> software without `--apply`, start background services, initialize git, or
> handle your credentials for you.

For the guided one-command workflow, run `./localclaw setup`. It checks and
installs prerequisites, checks for updates, bootstraps configuration, runs the
read-only doctor, and executes the regression and disposable E2E tests. Use
`./localclaw setup --apply-update` only after reviewing the update check.

Environment overrides use the `LOCALCLAW_` prefix. Use the LocalClaw names
documented in [`docs/INSTALL.md`](docs/INSTALL.md).

---

## Why this exists

Running an autonomous or semi-autonomous AI agent on a work machine is useful
but risky: agents can leak credentials, open network listeners, or take
irreversible actions. This project is an opinionated, auditable baseline that
makes the safe path the default:

- **Secrets stay in Vault**, reachable only through short-lived, session-scoped
  orphan tokens carrying least-privilege policies. The temporary administrator
  login token is revoked before the gateway starts.
- **The gateway is foreground-only and loopback-only.** Close the terminal and
  the session is over — the token is revoked and Vault is stopped.
- **Operational memory is summaries, not secrets**, with a retention window and
  a manual purge (no unattended cleanup).
- **Backups are optional and encrypted** with a private `age` identity that
  never lives in this repository.

## Security model at a glance

| Principle | How the stack applies it |
| --- | --- |
| Loopback only | Vault and the OpenClaw gateway bind to `127.0.0.1`; TLS is disabled *only* because the listener never leaves localhost. |
| No messaging channels | No inbound webhooks, chat bridges, or remote control surfaces. |
| No daemons / schedulers | No launchd/systemd unit, cron, or timer is installed. Sessions are foreground and operator-initiated. |
| Least privilege | Separate Vault policies for the human admin, the agent, and the backup token (`policies/`). |
| User-owned directories | Config and state live under your XDG dirs with `700`/`600` permissions. |
| Secret prompts only | Tokens and unseal shares are entered via hidden prompts and passed through the environment for a single command — never as CLI args or files. |
| Private key never in repo | The `age` backup identity is generated outside the repo; only the **public recipient** is referenced locally. |

Full details, including the trust boundary and the explicit non-goals, are in
[`docs/SECURITY.md`](docs/SECURITY.md).

## Architecture

A local Vault (Raft storage, loopback listener) holds secrets. A foreground
launcher unseals it, mints a least-privilege token, injects the needed secrets
into the OpenClaw gateway's environment **only**, and opens the terminal UI.
Exiting tears everything down. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
for Mermaid diagrams of the components, the session lifecycle, and the backup
flow.

```text
 you ──► scripts/work-session ──► unseal Vault (loopback) ──► mint agent token
                                        │                          │
                                        ▼                          ▼
                                  Raft storage            inject secrets into the
                                (owner-only dir)          FOREGROUND gateway only
                                        │                          │
                                        ▼                          ▼
                                 optional age-             OpenClaw TUI (loopback)
                              encrypted snapshot on exit
```

## Supported platforms

- **macOS** via [Homebrew][brew].
- **Ubuntu / Debian** via `apt` (plus HashiCorp's apt repository for Vault).

The scripts target Bash 3.2+ (so they run on the stock macOS shell) and avoid
Bash 4-only features. Exact tested OS versions are a
[maintainer decision](docs/MAINTAINER-DECISIONS.md).

## Prerequisites

Before running the installer, install the bootstrap tools: **Git** on every
platform, and **Homebrew on macOS**. Use the official Git instructions at
<https://git-scm.com/downloads>; on macOS, Apple's Command Line Tools also
provide Git (`xcode-select --install`). Install Homebrew from
<https://brew.sh/>. LocalClaw does not install either bootstrap tool for you.
Ubuntu/Debian uses `apt` for the remaining prerequisites.

The installer checks these first and, when you run `scripts/install --apply`,
installs any missing supported tools/services through Homebrew or apt. It asks
for an explicit `INSTALL` confirmation before making changes and may require
administrator permissions:

- `vault` — HashiCorp Vault CLI/server
- `sqlite3` — work-memory database
- `node`/`npm` — runtime used to install OpenClaw
- `jq`, `git`, `curl`, `tmux` — supporting CLI tools
- `age` and `age-keygen` — optional, for encrypted backups
- `tar`, `shasum`/`sha256sum` — packaging and integrity
- `openclaw` — the OpenClaw gateway/TUI from the official
  [install docs](https://docs.openclaw.ai/install). The LocalClaw installer uses
  the `extended-stable` channel: `npm install -g openclaw@extended-stable`.
- `shellcheck` — optional, for contributors

`scripts/install` first performs a complete read-only prerequisite check. With
no flag it prints the plan only; with `--apply` it installs missing tools and
the OpenClaw package via your package manager after confirmation. It does not
start background services or register them with launchd/systemd. Run `make
doctor` (or `scripts/doctor`) at any time — it is **read-only** and reports
what is present, missing, and whether permissions are correct.

## Quick start

> Read [`docs/INSTALL.md`](docs/INSTALL.md) first. Restore/disaster-recovery
> stays manual by design (see [`docs/BACKUP-RESTORE.md`](docs/BACKUP-RESTORE.md)).

For a complete, plain-language walkthrough—including the commands an automated
installer should run and the actions it must never automate—start with
[`docs/MANUAL-STEP-INSTALLATION.md`](docs/MANUAL-STEP-INSTALLATION.md).

1. **Install prerequisites** for your OS: `scripts/install` (plan only) then
   `scripts/install --apply` — or follow [`docs/INSTALL.md`](docs/INSTALL.md).
2. **Preflight:** `make doctor` — confirm tools, permissions, and disk
   encryption look right.
3. **Configure:** `scripts/bootstrap` renders config, creates owner-only state,
   and initializes the work-memory DB. Then edit `stack.conf` (and
   `secrets.map`) — see [`docs/CONFIGURATION.md`](docs/CONFIGURATION.md).
4. **Start Vault:** `make vault-start` in a dedicated terminal (foreground).
5. **Initialize Vault yourself.** `scripts/vault-bootstrap init` prints the
   exact `vault operator init`/`unseal` commands for *you* to run; record the
   recovery material in external custody. The stack never views or stores
   unseal/recovery material.
6. **Set up policies/roles:** `scripts/vault-bootstrap configure` writes the KV
   v2 mount, the three policies, your `userpass` admin, and the session token
   roles (you paste a privileged token at a hidden prompt). Then
   `scripts/vault-bootstrap revoke-root` after your admin login works.
7. **Work:** `make work-session` (or `scripts/work-session`) starts a foreground
   session — it owns Vault and the loopback gateway, opens the TUI, and on a
   clean exit runs guarded cleanup (encrypted backup, tokens revoked, Vault
   stopped). Validate first with `scripts/work-session --dry-run`.
8. **Back up / restore** as needed — the exit-time backup is automatic; take an
   ad-hoc one with `scripts/backup`. Inspect or restore a backup with
   `scripts/restore` (read-only by default; the destructive snapshot restore is
   gated behind `--restore` and an exact typed confirmation). See
   [`docs/BACKUP-RESTORE.md`](docs/BACKUP-RESTORE.md).
9. **Uninstall** (optional) — `scripts/uninstall` (plan-only by default) removes
   this stack's generated config/tool files while preserving your Vault data,
   work-memory DB, workspace, and backups.

Day-to-day commands and troubleshooting live in
[`docs/OPERATIONS.md`](docs/OPERATIONS.md).

## Repository layout

```text
.
├── README.md                     This file.
├── LICENSE                       GNU GPL v3.0 (GPL-3.0-or-later).
├── SECURITY.md                   How to report a vulnerability.
├── CHANGELOG.md                  Release notes / roadmap.
├── VERSION                       Current version (0.1.0).
├── Makefile                      Thin wrappers: doctor, vault-start, backup, restore, uninstall, check, test, clean.
├── .gitignore / .editorconfig    Repo hygiene (secrets & state never tracked).
├── config/
│   ├── stack.conf.example        Non-secret stack settings (copy & edit).
│   ├── vault.hcl.template         Loopback Vault server config (rendered).
│   ├── openclaw.json.example      Minimal foreground gateway config (rendered).
│   └── secrets.map.sample         ENV → Vault path map (names/paths only).
├── policies/
│   ├── admin.hcl                 Human operator (manage mount/policies/auth).
│   ├── agent.hcl                 Foreground agent token (least privilege).
│   └── backup.hcl                Snapshot-only backup token.
├── sql/
│   ├── schema.sql                Work-memory tables (summaries only).
│   ├── purge_expired.sql         Retention purge (run manually in-session).
│   └── README.md                 What belongs in memory; WAL/pragmas notes.
├── scripts/
│   ├── install                   Plan-by-default prerequisite installer (--apply).
│   ├── bootstrap                 Render config, create owner-only state, init DB.
│   ├── vault-bootstrap           Guide Vault init; write policies/roles; revoke root.
│   ├── doctor                    Read-only preflight checks (no changes).
│   ├── vault-start               Foreground, loopback-only Vault server.
│   ├── work-session              Foreground launcher (owns Vault + loopback gateway/TUI).
│   ├── backup                    age-encrypted Vault snapshot backup (Daily/Weekly).
│   ├── restore                   Inspect/restore a backup (read-only by default).
│   ├── uninstall                 Remove generated config/tool files (plan by default).
│   ├── update                    Safe fast-forward update to a release tag.
│   ├── ci-local                  Run CI locally: native-host tests + explicit Docker/Ubuntu image.
│   ├── release                   Version helper (VERSION + CHANGELOG only; never runs git).
│   └── lib/common.sh             Shared, Bash-3.2-safe helpers.
├── tests/                        Dependency-light suite (throwaway HOME; never real HOME/creds).
│   ├── run.sh lib.sh             Test runner + assertion helpers.
│   └── cases/                    Focused cases (syntax, dry-run, render, path-safety, retention, …).
├── docker/
│   └── Dockerfile.ci             Ubuntu test image (Linux only; macOS runs natively — see docs/CI-CD.md).
├── workspace-template/           Copy into your workspace; contains no secrets.
│   ├── AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md HEARTBEAT.md
│   └── memory/                   Empty by design (.gitkeep).
└── docs/
    ├── INSTALL.md CONFIGURATION.md SECURITY.md BACKUP-RESTORE.md
    ├── OPERATIONS.md ARCHITECTURE.md CONTRIBUTING.md
    ├── CI-CD.md VERSIONING.md     Pipeline, local CI, SemVer, and release flow.
    └── MAINTAINER-DECISIONS.md   Checklist to complete before publishing.
```

## What this project deliberately does **not** do

- It does not install packages without an explicit `--apply` (and a typed
  confirmation), and never by piping a download into a shell. It installs
  missing supported prerequisites, but does not start background services or
  initialize git for you.
- It does not view, store, or transmit your unseal shares, recovery keys, root
  token, API keys, or private `age` identity.
- It does not open any non-loopback listener or add TLS-less remote endpoints.
- It does not run anything unattended: no cron, launchd, systemd, or timers.

## Testing, CI/CD, and releases

The stack ships a dependency-light, Bash-3.2-safe test-suite that **never uses
your real `HOME`, real credentials, a real Vault, or the network** — every case
runs against a throwaway sandbox home.

```sh
make test                 # run the whole suite (bash tests/run.sh)
tests/run.sh -v 50-restore # verbose; run a subset by name fragment
scripts/ci-local native    # run the native-host checks (lint + tests) as CI does
scripts/ci-local build && scripts/ci-local ubuntu   # explicit Ubuntu-in-Docker run
```

Run the same checks locally with `make test`, `make check`, and
[`scripts/ci-local`](scripts/ci-local). A sample CI configuration is included
for providers that support shell checks, Ubuntu containers, secret scanning,
packaging, and tag-gated releases. See [`docs/CI-CD.md`](docs/CI-CD.md) and
[`docs/VERSIONING.md`](docs/VERSIONING.md).

## Security & support

Report vulnerabilities privately per [`SECURITY.md`](SECURITY.md); expect an
initial acknowledgement **within 1–2 weeks**. The project maintainer and
security contact is **Christopher Welle**
(cjwelle@gmail.com). Security support tracks **published
release lines** — this project is **`0.1.0`**, so the **`0.1.x`** line is
supported and earlier/unreleased versions are not. `VERSION` is the canonical
SemVer source of truth. The running system's security model is in
[`docs/SECURITY.md`](docs/SECURITY.md).

## License

Licensed under the **GNU General Public License v3.0 or later**
(`SPDX-License-Identifier: GPL-3.0-or-later`). The full text is in
[`LICENSE`](LICENSE).

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. It is distributed in the hope that it will be useful, but **WITHOUT ANY
WARRANTY**; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License for more details.

## Contributing

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md). In short: keep everything
loopback-only, least-privilege, and secret-free; never commit runtime state or
credentials; and run `make doctor`, `make check`, and `make test` before opening
a merge request.

[vault]: https://developer.hashicorp.com/vault
[sqlite]: https://www.sqlite.org/
[age]: https://age-encryption.org/
[brew]: https://brew.sh/
