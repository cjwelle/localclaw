# Installation

> **Start here if you want the full guided path:**
> [`SELF-HOSTING.md`](SELF-HOSTING.md) walks from a fresh clone through Vault,
> the first OpenClaw session, backups, tests, and GitLab automation. This file
> remains the detailed prerequisite and platform reference.

> **Official OpenClaw resources** (this repo is an independent hardening layer,
> not a fork): project <https://openclaw.ai/> · install docs
> <https://docs.openclaw.ai/install> · installer <https://openclaw.ai/install.sh>.
> Prefer the upstream docs for OpenClaw itself; always review any downloaded
> installer before running it (never curl-pipe into a shell). See §4.

You can let `scripts/install` **plan** the setup for you (it prints the exact
package-manager commands and changes nothing), or follow the manual commands in
this guide. Either way, review each command before running it.

`scripts/install` is safe by default: with no flags it only prints a plan.
It installs anything **only** under `--apply`, after a typed `INSTALL`
confirmation, and never by piping a download into a shell. It does not install
OpenClaw (not in package managers — see §4), start a background service,
register a scheduler, or touch your credentials.

```sh
scripts/install            # plan only (default): prints what it would do
scripts/install --apply    # install missing tools after a typed confirmation
```

## Quick Start

New to this stack? This is the fastest path from a fresh clone to a working
session. Each step is explained in more depth later in this file and in
[`CONFIGURATION.md`](CONFIGURATION.md), [`OPERATIONS.md`](OPERATIONS.md), and
[`SECURITY.md`](SECURITY.md) — read those before you trust this with real
secrets. Run the commands below in order, from the repo root.

1. **Clone the repo and enter it.**

   ```sh
   git clone <this-repo-url>
   cd openclaw-secure-local-stack
   ```

2. **See what `scripts/install` would do, then let it install missing tools**
   (§1–§3). It only prints a plan by default; `--apply` still requires you to
   type `INSTALL` before it changes anything:

   ```sh
   scripts/install            # plan only — changes nothing
   scripts/install --apply    # installs missing tools after a typed confirmation
   ```

3. **Install OpenClaw** from the official upstream sources (§4). This stack
   wraps OpenClaw but does not install it for you.

4. **Render your local config.** This creates your owner-only config/state
   directories, seeds `stack.conf` and `secrets.map` from the shipped
   samples (only if they don't already exist), and initializes the
   work-memory database:

   ```sh
   scripts/bootstrap
   ```

5. **Edit `stack.conf` and `secrets.map`** for your setup (ports, KV mount
   name, which provider keys get injected into the gateway). Both files live
   under your `XDG_CONFIG_HOME`, never in the repo — see
   [`CONFIGURATION.md`](CONFIGURATION.md) for every key and what it does.

6. **Start Vault, then initialize and configure it yourself.** In one
   terminal, start Vault and leave it running:

   ```sh
   scripts/vault-start
   ```

   In a second terminal:

   ```sh
   scripts/vault-bootstrap init       # prints the exact init/unseal commands for YOU to run
   #   ...you run the printed `vault operator init` and `vault operator
   #   unseal` commands yourself — read "Where do the root token and unseal
   #   shares come from?" below before you do...
   scripts/vault-bootstrap configure  # sets up the KV mount, policies, admin user, token roles
   ```

7. **Verify everything** with the read-only preflight:

   ```sh
   scripts/doctor
   ```

   Fix any `[FAIL]` line; `[WARN]` lines are advisory (e.g. backups not
   configured yet).

8. **Run the end-to-end test** to confirm the full lifecycle works on your
   machine:

   ```sh
   tests/e2e/run.sh
   ```

   This does **not** touch the Vault you just initialized — see "The E2E test
   uses a disposable Vault only" below.

Once `scripts/doctor` is clean, start a normal work session with
`scripts/work-session` (or `make work-session`) — see
[`OPERATIONS.md`](OPERATIONS.md) for what it does at each step.

### Where do the Vault root token and unseal shares come from?

`scripts/vault-bootstrap init` never runs `vault operator init` for you — it
only prints the exact command and lets **you** run it. When you do, Vault
itself prints, once:

- a **root token** (full admin access to this local Vault), and
- `VAULT_KEY_SHARES` **unseal key shares** (default `5`), of which you must
  supply `VAULT_KEY_THRESHOLD` of them (default `3`) to unseal Vault every
  time it starts.

Nothing in this repo — no script, no log, no database — ever sees or stores
that output. Copy it immediately into a **password manager or other secure
recovery location** you control, the same way you'd protect any other master
credential. If you lose enough unseal shares to fall below the threshold and
Vault ever seals again, your secrets are unrecoverable. Once
`scripts/vault-bootstrap configure` has created your admin login and you've
confirmed it works, revoke the root token with
`scripts/vault-bootstrap revoke-root` and delete it from your password
manager — keep the unseal shares.

> **Future credential providers.** This stack has no built-in integration
> with any specific password-manager product — you copy the root token,
> unseal shares, and any `age` backup identity into whichever secret manager
> you already use, by hand. **Bitwarden** used this way is the currently
> supported/current pattern. Dedicated, optional integrations for
> **1Password** and **LastPass** are planned but **not implemented yet** —
> there is no scripted `op` or LastPass CLI workflow in this repo today.

### The E2E test uses a disposable Vault only

`tests/e2e/run.sh` starts its **own throwaway Vault** in dev mode on a
loopback port it picks itself, seeded with a fixed, non-secret test password
and a fixed test API key. It never reads your `stack.conf` or `secrets.map`,
never talks to the Vault you initialized in step 6, and tears the whole thing
down — Vault process, mock gateway, temporary `HOME` — when it exits. It is
safe to run at any time, on any machine, including in CI.

## 1. Prerequisites

| Tool | Purpose | Required? |
| --- | --- | --- |
| `vault` | Local secrets engine (server + CLI) | Yes |
| `sqlite3` | Work-memory database | Yes |
| `node`, `npm` | Runtime to install/run OpenClaw | Yes (for OpenClaw) |
| `jq` | JSON parsing in scripts | Yes |
| `git`, `curl` | Repo tooling / fetching the Vault apt key | Yes |
| `tmux` | Terminal session management | Yes |
| `tar` | Packaging backups | Yes (for backups) |
| `shasum` or `sha256sum` | Integrity checks | Yes |
| `age`, `age-keygen` | Encrypted backups | Optional (backups) |
| `openclaw` | The gateway / terminal UI | Yes (official npm package) |
| `shellcheck` | Linting scripts (contributors) | Optional |

## 2. macOS (Homebrew)

Install [Homebrew](https://brew.sh/) first if you do not have it, then:

```sh
# Vault comes from HashiCorp's tap.
brew tap hashicorp/tap
brew install hashicorp/tap/vault

# Runtime for OpenClaw, plus supporting CLI tools.
brew install node jq git curl tmux

# Backups and database.
brew install age
# sqlite3 ships with macOS; install the Homebrew build only if you want a newer one:
# brew install sqlite

# Optional: for contributors.
brew install shellcheck
```

> **Do not** register Vault as a Homebrew service. This stack runs Vault in the
> foreground only. If you previously ran `brew services start vault`, stop and
> remove it: `brew services stop vault`.

macOS ships Bash 3.2 as `/bin/bash`; the scripts are written to run on it. You do
**not** need to install a newer Bash.

Enable **FileVault** full-disk encryption before storing any secrets
(System Settings → Privacy & Security → FileVault). `scripts/doctor` checks this.

## 3. Ubuntu / Debian (apt)

Vault is distributed from HashiCorp's apt repository:

```sh
sudo apt-get update
sudo apt-get install -y gpg curl lsb-release

# Add HashiCorp's GPG key and apt repository (review before running).
curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update
sudo apt-get install -y vault sqlite3 age tar coreutils \
  nodejs npm jq git curl tmux

# Optional: for contributors.
sudo apt-get install -y shellcheck
```

> Installing the `vault` package may create a systemd unit. This stack does not
> use it. Ensure it is **not** enabled or running:
>
> ```sh
> sudo systemctl disable --now vault 2>/dev/null || true
> ```

Enable **full-disk encryption** (LUKS) before storing secrets. `scripts/doctor`
attempts to detect an encrypted block device.

## 4. Install OpenClaw

OpenClaw is a **separate upstream project**; this stack only wraps it. Always use
the official sources for the canonical package name and installation steps:

- Project: <https://openclaw.ai/>
- Install docs: <https://docs.openclaw.ai/install>
- Development / release channels: <https://docs.openclaw.ai/install/development-channels>
- Official installer script: <https://openclaw.ai/install.sh>

OpenClaw is not distributed through Homebrew or apt. After Node/npm is ready,
the confirmed `scripts/install --apply` workflow installs the official npm
package shown in the upstream documentation.

### Release channel

This stack **defaults to the `extended-stable` release channel** for stability
rather than the rolling `@latest` tag. Install by pinning that npm dist-tag:

```sh
npm install -g openclaw@extended-stable
```

To move an existing install onto (or keep it on) the same channel:

```sh
openclaw update --channel extended-stable
```

Choosing `extended-stable` is a **documented default, not a lock-in**: if you
have a specific reason to track a faster-moving channel, you may override it
(e.g. `npm install -g openclaw@latest` or `openclaw update --channel <other>`).
Review the trade-offs first — the available channels and their release cadence
are described at <https://docs.openclaw.ai/install/development-channels>.
If your npm global prefix needs a different user context, run the command
manually; avoid `sudo npm` unless your organization explicitly manages npm that
way.

If you prefer the official installer script, **download and read it before
running it** — never pipe it straight into a shell:

```sh
# Review, then run the reviewed copy — do NOT `curl ... | sh`.
curl -fsSL https://openclaw.ai/install.sh -o /tmp/openclaw-install.sh
less /tmp/openclaw-install.sh          # read it end to end
sh /tmp/openclaw-install.sh            # run only after you have reviewed it
```

Make sure the `openclaw` binary is on your `PATH`. The stack treats a missing
`openclaw` as a warning (not a hard failure) so you can set up Vault first, and
it expects sessions to stay **foreground-only** (no gateway service).

## 5. Verify

Run the read-only preflight — it makes no changes:

```sh
make doctor      # or: scripts/doctor
```

Fix any `[FAIL]` lines (missing tools, wrong permissions). `[WARN]` lines are
advisory (e.g. OpenClaw not yet installed, backups not configured).

## 6. Next steps

1. [`CONFIGURATION.md`](CONFIGURATION.md) — copy and edit `stack.conf`, render
   templates, and initialize the work-memory database.
2. Initialize and unseal Vault **yourself** (the stack never handles unseal or
   recovery material). See [`SECURITY.md`](SECURITY.md) and
   [`OPERATIONS.md`](OPERATIONS.md).
3. Apply the policies in [`../policies/`](../policies/) and create your KV v2
   mount and auth role.
