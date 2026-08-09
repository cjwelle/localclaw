# Installation

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
