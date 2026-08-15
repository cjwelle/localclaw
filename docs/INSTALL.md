# Installation

> **Start here if you want the full guided path:**
> [`MANUAL-STEP-INSTALLATION.md`](MANUAL-STEP-INSTALLATION.md) walks from a fresh clone through Vault,
> the first OpenClaw session, backups, and tests. This file
> remains the detailed prerequisite and platform reference.

> **Official OpenClaw resources** (this repo is an independent hardening layer,
> not a fork): project <https://openclaw.ai/> · install docs
> <https://docs.openclaw.ai/install> · installer <https://openclaw.ai/install.sh>.
> Prefer the upstream docs for OpenClaw itself; always review any downloaded
> installer before running it (never curl-pipe into a shell). See §4.

You can let `./localclaw install` **plan** the setup for you (it prints the exact
package-manager commands and changes nothing), or follow the manual commands in
this guide. Either way, review each command before running it.

`localclaw` is the recommended command entry point. It provides the same simple
install/update/doctor shape as OpenClaw while keeping this stack's explicit
safety prompts. The underlying `scripts/*` commands remain available for
automation and troubleshooting.

For a new machine, the guided command runs the full sequence in one flow:

```sh
./localclaw setup
```

It checks and installs prerequisites, checks for a release update, bootstraps
configuration, runs `doctor`, the regression suite, and the disposable E2E
lifecycle test. It does not apply a code update unless you explicitly pass
`--apply-update`; review the update check first. Use `--skip-tests` or
`--skip-e2e` only when you have a specific reason.

## Bootstrap prerequisites

Before running any LocalClaw installer command, install these tools:

1. **Git**, so you can clone the repository and pull future updates. Use the
   official instructions at <https://git-scm.com/downloads>. On macOS, Apple's
   Command Line Tools also provide Git; install them with `xcode-select
   --install`.
2. **Homebrew on macOS**, because LocalClaw uses it to install Vault, age, and
   the other macOS prerequisites. Follow the official instructions at
   <https://brew.sh/>. Homebrew is not installed automatically by LocalClaw.

Ubuntu/Debian systems use `apt` instead of Homebrew. Git is still required
before running the installer. After installing these bootstrap prerequisites,
clone the repository and run `./localclaw setup`.

### Windows Subsystem for Linux (WSL)

LocalClaw may work inside the Ubuntu distribution provided by WSL. Use the
Ubuntu/Debian instructions and run all commands from the Linux shell, not from
Windows PowerShell or Command Prompt. This path should work in principle, but
WSL has not been fully tested or validated by the project. Windows-native
execution is not currently supported.

## Installer behavior

Environment overrides use the `LOCALCLAW_` prefix, for example
`LOCALCLAW_CONFIG_DIR`, `LOCALCLAW_STATE_DIR`, `LOCALCLAW_WORKSPACE_DIR`, and
`LOCALCLAW_UPDATE_REMOTE`.

`./localclaw install` is safe by default: it first performs a complete, read-only
prerequisite check and then prints the installation plan. It installs missing
supported tools and the official OpenClaw package **only** under `--apply`,
after you explicitly type `INSTALL` at the confirmation prompt. In an
interactive run, it may also prompt you to choose a password manager and a
backup destination; press Enter or choose the displayed defer/disable option
to leave either unconfigured. It may require `sudo` on Ubuntu/Debian or
administrator approval through Homebrew. It never pipes a download into a
shell, does not start a background service or register a scheduler, and does
not touch your credentials.

```sh
./localclaw install             # plan only (default): prints what it would do
./localclaw install --apply     # install missing tools after confirmation
./localclaw doctor              # read-only health check
./localclaw update --check      # check release tags without changing anything
```

During an interactive run, the installer asks which password manager you use
(`none`, `bitwarden`, `1password`, or `lastpass`). The prerequisite report
always checks all three supported CLIs (`bw`, `op`, and `lpass`) so you can see
what is already installed. Only the provider you select is included in the
installation plan. When Bitwarden is installed, it also runs the read-only
`bw status` check and reports whether Bitwarden is logged out, locked, or
unlocked. It never logs in, asks for your master password, or stores a session
key. The status check is bounded so a stuck provider CLI cannot pause the
installer. For automation, pass the choice explicitly:

```sh
./localclaw install --password-manager bitwarden
./localclaw install --apply --password-manager 1password
```

### Bitwarden login and unlock

If the installer reports that Bitwarden is not logged in, authenticate with
Bitwarden directly:

```sh
bw login
```

If it reports that Bitwarden is locked, unlock it interactively:

```sh
bw unlock
```

Then rerun `./localclaw doctor` or the installer. Complete any required MFA,
security-key, or device approval yourself. Do not put the master password or
`BW_SESSION` value in Git, `stack.conf`, logs, or documentation.

The installer also checks and installs the local backup prerequisites: `age`,
`age-keygen`, Vault, `tar`, and a checksum utility (`shasum` or `sha256sum`).
On Ubuntu, Bitwarden is installed through its official npm CLI package,
LastPass through apt, and 1Password through its official signed apt repository
when selected. On macOS, the selected provider CLI is
installed with Homebrew. Provider account sign-in and MFA remain a separate,
interactive step; the installer never asks for or stores those credentials.

## Quick Start: complete first installation

This is the canonical path from a clean OS to the first real LocalClaw
session. `./localclaw setup` handles software installation, local config
creation, doctor, regression tests, and a disposable E2E test. It does **not**
initialize or configure your real Vault; the remaining steps do that safely and
manually.

The distinction between the guides is simple:

- This Quick Start is the recommended end-to-end sequence using `./localclaw`.
- [`MANUAL-STEP-INSTALLATION.md`](MANUAL-STEP-INSTALLATION.md) explains the
  same lifecycle at a lower level, with individual commands, safety rationale,
  recovery guidance, and automation notes. Use it when troubleshooting or when
  you intentionally do not want the guided setup.

Run these steps in order from the repository root.

### 1. Clone and run guided setup

Install Git and Homebrew first on macOS (or Git and the normal apt bootstrap
prerequisites on Ubuntu/Debian), then:

```sh
git clone <this-repo-url> localclaw
cd localclaw
./localclaw setup
```

During setup, the installer may ask you to select a password-manager CLI and a
backup destination, then requires you to type `INSTALL` before packages are
installed. Setup does not ask for your password-manager master password,
Bitwarden session, Vault root token, or unseal shares.

At the end, review `./localclaw doctor`. Warnings about an unconfigured backup
recipient are expected until Step 4. The E2E result is disposable and does not
prove that your real Vault is initialized.

### 2. Log in to the selected password-manager CLI

The installer installs the selected CLI; it does not authenticate it. Use the
vendor's official instructions and complete MFA/security-key approval yourself:

- [Bitwarden CLI documentation](https://bitwarden.com/help/cli/): `bw login`,
  then `bw unlock` when the vault is locked.
- [1Password CLI documentation](https://developer.1password.com/docs/cli/):
  authenticate with `op account add`/`op signin` as appropriate for your
  account and desktop integration.
- [LastPass CLI documentation](https://github.com/lastpass/lastpass-cli):
  authenticate with `lpass login`.

Sample login flows:

```sh
# Bitwarden
bw login you@example.com
export BW_SESSION="$(bw unlock --raw)"
bw status

# 1Password
op account add --address my.1password.com --email you@example.com
op read "op://Private/LocalClaw-backup-identity/notes"

# LastPass
lpass login you@example.com
lpass status
```

Pick the provider you actually use, log into that provider first, and then use
only the matching `credentials configure` command below. The login step and the
configure step are separate: login authenticates the provider CLI, while
`credentials configure` stores the provider-specific reference to your secure
note.

Check the selected CLI without exposing credentials:

```sh
./localclaw credentials status
./localclaw doctor
```

CLI authentication is separate from LocalClaw's optional backup-key adapter.
To use a password manager for encrypted-backup verification, first generate an
age identity as described in [`BACKUP-RESTORE.md`](BACKUP-RESTORE.md), store the
private identity in one secure note, and then configure only its provider-native
reference:

```sh
./localclaw credentials configure \
  --provider bitwarden \
  --ref 'LocalClaw backup identity'
```

Use the matching `1password` or `lastpass` provider and reference format when
applicable. Never put the private identity, master password, session token,
Vault root token, or unseal shares in `stack.conf`.

### 3. Bootstrap and initialize the real Vault

`./localclaw setup` normally already ran bootstrap. If you skipped it or want
to rerun it safely:

```sh
./localclaw bootstrap
```

Review the generated owner-only files:

```sh
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/localclaw"

# Set these if your shell does not already define an editor.
export EDITOR="nano"
export VISUAL="nano"

$EDITOR "$CFG/stack.conf"
$EDITOR "$CFG/secrets.map"
```

`EDITOR` and `VISUAL` must be set to an editor command before running the two
commands above. Otherwise, zsh may try to execute the filenames and report a
permission or command error. The exports above apply only to the current
terminal. To set Nano permanently for future zsh sessions, add them to
`~/.zshrc` and reload the file:

```sh
printf '\nexport EDITOR="nano"\nexport VISUAL="nano"\n' >> ~/.zshrc
source ~/.zshrc
```

If you use VS Code instead, use `export EDITOR="code --wait"` and
`export VISUAL="code --wait"`.

Keep Vault loopback-only (`VAULT_HOST=127.0.0.1`). `secrets.map` contains only
Vault paths and field names, never secret values. Add the public age recipient
and confirm `BACKUP_DIR` if you enabled backups.

Start the real, foreground Vault in terminal 1:

```sh
./localclaw vault-start
```

In terminal 2, print the initialization instructions:

```sh
./localclaw vault-bootstrap init
```

Run the printed `vault operator init` command yourself. Save the root token and
the required unseal shares in secure external custody. Then run the printed
`vault operator unseal` command with enough different shares to reach the
threshold. LocalClaw does not capture or store this material.

If you are following the flow manually, the unseal command is the standard
Vault CLI command and you run it once per share:

```sh
vault operator unseal
```

If you need to stop the foreground Vault from another terminal, use:

```sh
./localclaw vault-stop
```

Configure the KV mount, policies, admin login, and short-lived session roles:

```sh
./localclaw vault-bootstrap configure
```

After confirming the admin login works, revoke the initial root token:

```sh
./localclaw vault-bootstrap revoke-root
```

Keep the unseal shares. They are required if Vault seals again.

Once the admin login exists, the stack mints its short-lived least-privilege
session tokens with the standard Vault CLI token-create flow:

```sh
vault token create -role=agent-session -policy=agent -ttl=8h
vault token create -role=backup-session -policy=backup -ttl=8h
```

Those are the same roles the launcher uses later for the foreground gateway and
the backup path.

### 4. Add the secrets that OpenClaw should receive

Use the Vault CLI with an approved operator/admin token supplied interactively.
The exact path must match the mount/path/field entries in `secrets.map`:

```sh
export VAULT_ADDR="http://127.0.0.1:18200"
vault kv put local/ai/openai api_key='PASTE_VALUE_INTERACTIVELY'
unset VAULT_ADDR VAULT_TOKEN
```

Do not paste real secrets into shell history, chat, Git, or `secrets.map`.

### 5. Verify and run the first real session

```sh
./localclaw doctor
./localclaw work-session --dry-run
./localclaw work-session
```

The real work session starts its owned foreground Vault/gateway lifecycle,
unseals Vault, authenticates, mints short-lived least-privilege tokens, injects
only the mapped secrets, and opens the OpenClaw terminal UI. Exit with `/exit`,
Ctrl-D, or the documented Ctrl-C sequence. Cleanup revokes temporary tokens,
takes an encrypted backup if fully configured, and stops the processes.

### 6. Verify backups and keep operating safely

If backups are configured, exit a successful session once and confirm a
ciphertext archive appears under `BACKUP_DIR/Daily/`. Then verify it:

```sh
./localclaw backup verify /absolute/path/to/backup.tar.gz.age
```

Read [`BACKUP-RESTORE.md`](BACKUP-RESTORE.md) before any restore operation.
For normal operation and updates, use [`OPERATIONS.md`](OPERATIONS.md).

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

> **Password-manager adapters.** The optional `localclaw credentials` workflow
> supports Bitwarden, 1Password, and LastPass for retrieving the private age
> identity during backup verification. It does not store provider passwords,
> session tokens, or unseal shares. See the step-by-step setup in
> [`BACKUP-RESTORE.md`](BACKUP-RESTORE.md).

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
| `bw` | Bitwarden backup-key retrieval | Optional (if using Bitwarden) |
| `op` | 1Password backup-key retrieval | Optional (if using 1Password) |
| `lpass` | LastPass backup-key retrieval | Optional (if using LastPass) |
| `openclaw` | The gateway / terminal UI | Yes (official npm package) |
| `shellcheck` | Linting scripts (contributors) | Optional |

### Password-manager prerequisites

The Bitwarden, 1Password, and LastPass integrations are optional. To use one,
you must have all of the following before running `./localclaw credentials configure`:

1. An active account with the provider you selected. The account must be able
   to read a secure note in its vault; organization-managed accounts must also
   permit CLI access.
2. The provider's official CLI installed and available on `PATH` (`bw`, `op`,
   or `lpass`).
3. Your provider master password plus any required MFA, security key, or
   desktop approval. LocalClaw does not bypass provider authentication.
4. `age` and `age-keygen`, plus the local `vault`, `tar`, and checksum tools.
5. An age private identity saved in the provider and its matching public
   recipient configured locally. The private identity must be a complete,
   single key—not a password, unseal share, or mixed note.
6. A bootstrapped LocalClaw installation and at least one encrypted backup made with
   that matching public recipient. Run `./localclaw doctor` before setup.

The provider CLI may need network access on its first sign-in. Do not place
provider passwords, session tokens, age private identities, or Vault unseal
shares in `stack.conf`, Git, shell history, or command-line arguments. Follow
the detailed setup and verification procedure in
[`BACKUP-RESTORE.md`](BACKUP-RESTORE.md).

## 2. macOS (Homebrew)

Install [Homebrew](https://brew.sh/) first if you do not have it, then:

```sh
# Vault comes from HashiCorp's tap. Refresh the tap first if an older local
# copy reports an unrelated formula-import error such as vagrant.rb.
brew untap hashicorp/tap 2>/dev/null || true
brew tap hashicorp/tap
brew install hashicorp/tap/vault

# If the tap reports an unrelated formula-import error such as vagrant.rb:
# brew update
# brew tap --repair
# brew install hashicorp/tap/vault

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

OpenClaw is a **separate upstream project**; this stack wraps it and can install
the official npm package when it is missing. Always use the official sources
for the canonical package name and installation steps:

- Project: <https://openclaw.ai/>
- Install docs: <https://docs.openclaw.ai/install>
- Development / release channels: <https://docs.openclaw.ai/install/development-channels>
- Official installer script: <https://openclaw.ai/install.sh>

OpenClaw is not distributed through Homebrew or apt. After Node/npm is ready,
the confirmed `scripts/install --apply` workflow installs the official npm
package shown in the upstream documentation. The installer does not create a
launchd/systemd service or run OpenClaw in the background; start sessions
explicitly with the documented foreground workflow.

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
