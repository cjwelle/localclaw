# Manual-Step Installation: from zero to a working stack

This is the plain-language, copy-and-check guide for installing the stack on a
new Mac or Ubuntu machine. It explains both the commands a person runs and the
checks that automation should perform. Start here if you are new to the
repository; use the linked specialist documents when you need the details.

The Ubuntu instructions may also work inside WSL. WSL is not fully tested or
validated, so use the Ubuntu/Linux shell and treat any WSL-specific behavior as
unsupported until verified. Windows-native execution is not supported.

## What you are installing

The stack runs two local foreground processes:

1. Vault stores secrets in an owner-only local Raft directory.
2. OpenClaw runs in a foreground gateway/TUI session and receives only the
   secrets listed in `secrets.map`.

Both listeners bind to `127.0.0.1`. Closing the session stops both processes and
revokes the temporary agent and backup tokens. Nothing is installed as a
daemon, cron job, launch agent, or systemd service by this repository.

## Before you start

You need:

- a dedicated local user account;
- full-disk encryption enabled (FileVault on macOS, LUKS on Ubuntu when
  possible);
- a secure place outside this repository for Vault recovery material;
- network access only for installing packages and OpenClaw.

Never put a Vault token, unseal share, API key, password, `age` private key, or
rendered runtime config in git, a ticket, a chat message, or a CI variable.

## Step 1: get the source

```sh
git clone <repository-url> localclaw
cd localclaw
```

Confirm the checkout is clean before you begin:

```sh
git status --short
```

## Step 2: install prerequisites

First print the platform-specific installation plan:

```sh
scripts/install
```

Read the output. If it is correct, apply it:

```sh
scripts/install --apply
```

The installer is plan-by-default. `--apply` requires an explicit confirmation;
it installs missing supported prerequisites and OpenClaw, but does not start
services or create credentials.

If you prefer to install manually, follow the platform-specific steps below.
`QuickStartInstall.md` now stays focused on the prerequisite matrix and installer
behavior; this file carries the actual install commands.

### macOS (Homebrew)

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

Do **not** register Vault as a Homebrew service. This stack runs Vault in the
foreground only. If you previously ran `brew services start vault`, stop and
remove it:

```sh
brew services stop vault
```

macOS ships Bash 3.2 as `/bin/bash`; the scripts are written to run on it. You
do **not** need to install a newer Bash.

Enable **FileVault** full-disk encryption before storing any secrets
(System Settings → Privacy & Security → FileVault). `scripts/doctor` checks this.

### Ubuntu / Debian (apt)

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

Installing the `vault` package may create a systemd unit. This stack does not
use it. Ensure it is not enabled or running:

```sh
sudo systemctl disable --now vault 2>/dev/null || true
```

Enable **full-disk encryption** (LUKS) before storing secrets. `scripts/doctor`
attempts to detect an encrypted block device.

### Install OpenClaw

OpenClaw is a separate upstream project. Use the official sources for the
canonical package name and installation steps:

- Project: <https://openclaw.ai/>
- Install docs: <https://docs.openclaw.ai/install>
- Development / release channels: <https://docs.openclaw.ai/install/development-channels>
- Official installer script: <https://openclaw.ai/install.sh>

OpenClaw is not distributed through Homebrew or apt. After Node/npm is ready,
the confirmed `scripts/install --apply` workflow installs the official npm
package shown in the upstream documentation. The installer does not create a
launchd/systemd service or run OpenClaw in the background; start sessions
explicitly with the documented foreground workflow.

This stack defaults to the `extended-stable` release channel for stability
rather than the rolling `@latest` tag. Install by pinning that npm dist-tag:

```sh
npm install -g openclaw@extended-stable
```

To move an existing install onto, or keep it on, the same channel:

```sh
openclaw update --channel extended-stable
```

Choosing `extended-stable` is a documented default, not a lock-in. If you have
a specific reason to track a faster-moving channel, you may override it
(for example `npm install -g openclaw@latest` or `openclaw update --channel <other>`).
Review the trade-offs first; the available channels and their release cadence
are described at <https://docs.openclaw.ai/install/development-channels>.
If your npm global prefix needs a different user context, run the command
manually; avoid `sudo npm` unless your organization explicitly manages npm that
way.

If you prefer the official installer script, download and read it before
running it. Never pipe it straight into a shell:

```sh
# Review, then run the reviewed copy - do NOT `curl ... | sh`.
curl -fsSL https://openclaw.ai/install.sh -o /tmp/openclaw-install.sh
less /tmp/openclaw-install.sh          # read it end to end
sh /tmp/openclaw-install.sh            # run only after you have reviewed it
```

Make sure the `openclaw` binary is on your `PATH`. The stack treats a missing
`openclaw` as a warning (not a hard failure) so you can set up Vault first, and
it expects sessions to stay foreground-only (no gateway service).

## Step 3: verify the machine

Run the read-only check:

```sh
make doctor
```

Fix every `[FAIL]`. Warnings are normally optional items such as backups not
being configured. Do not continue until the required commands (`vault`, `jq`,
`tmux`, `sqlite3`, and `openclaw`) are available.

For automation, treat a non-zero exit from `scripts/doctor` as a hard stop. Do
not automatically install missing packages or change permissions without an
explicit operator-approved install step.

## Step 4: render local configuration

```sh
scripts/bootstrap
```

This creates owner-only config/state directories outside the repository and
renders:

- `stack.conf` — non-secret ports and paths;
- `vault.hcl` — the loopback Vault server configuration;
- `openclaw.json` — the minimal local OpenClaw configuration;
- `secrets.map` — names of secrets to inject, not their values.

Edit the two files intended for operators:

```sh
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/localclaw"
$EDITOR "$CFG/stack.conf"
$EDITOR "$CFG/secrets.map"
```

Keep `VAULT_HOST=127.0.0.1`. Put only Vault paths and field names in
`secrets.map`, for example:

```text
OPENAI_API_KEY ai/openai api_key
```

The actual value belongs in Vault, never in this file.

## Step 5: initialize Vault once

Start Vault in terminal 1 and leave it running:

```sh
scripts/vault-start
```

In terminal 2, ask the helper to print the initialization commands:

```sh
scripts/vault-bootstrap init
```

Review and run the printed `vault operator init` command yourself. Save the
root token and the required number of unseal shares in secure external custody.
The repository must never receive them.

Then unseal Vault by running the printed `vault operator unseal` command with
enough different shares to reach the threshold.

If you are doing this manually, set `VAULT_ADDR` to the local listener first,
then run the standard Vault CLI command once per share:

```sh
export VAULT_ADDR="http://127.0.0.1:18200"
vault operator unseal
```

Optional: if you need to stop the foreground Vault from the second terminal,
use:

```sh
scripts/vault-stop
```

Configure the local KV mount, policies, admin login, and short-lived session
roles:

```sh
scripts/vault-bootstrap configure
```

The script asks for a privileged Vault token through a hidden prompt. Verify
the configuration:

```sh
scripts/doctor
```

After confirming that the admin login works, revoke the root token:

```sh
scripts/vault-bootstrap revoke-root
```

Do not revoke the unseal shares; they are needed if Vault seals again.

If you are using a password manager, store the recovery material as separate
items so you do not paste the wrong value later:

- one entry for the **root token**;
- one entry for each **unseal share** (`unseal share 1`, `unseal share 2`,
  and so on);
- a clear label such as `LocalClaw Vault recovery`;
- a dedicated folder/vault if your provider supports one.

Do not combine the root token, unseal shares, backup identity, or unrelated
secrets in the same record.

After the admin login exists, keep `VAULT_ADDR` pointed at the local listener
and mint the same short-lived least-privilege session tokens with the standard
Vault CLI token-create flow:

Use `export`, not `set`, so the address stays in scope for the later Vault
commands in the same shell.

```sh
export VAULT_ADDR="http://127.0.0.1:18200"
vault token create -role=agent-session -policy=agent -ttl=8h
vault token create -role=backup-session -policy=backup -ttl=8h
```

Those are the roles used by the foreground gateway and backup path.

## Step 6: add secrets to Vault

Use the Vault CLI with a privileged operator token supplied interactively or by
your approved secret manager. Set `VAULT_ADDR` first, then use the exact path
that matches the mount/path/field entries in `secrets.map`:

```sh
export VAULT_ADDR="http://127.0.0.1:18200"
vault kv put local/ai/openai api_key='PASTE_VALUE_INTERACTIVELY'
unset VAULT_TOKEN VAULT_ADDR
```

Use the mount configured in `stack.conf`. `secrets.map` must refer to the same
mount/path structure. Check the map without printing values:

```sh
sed -n '1,120p' "$CFG/secrets.map"
```

## Step 7: run the first real session

Validate without starting anything:

```sh
scripts/work-session --dry-run
```

Start the session:

```sh
scripts/work-session
```

The launcher will:

1. start its owned Vault process;
2. ask for unseal shares;
3. ask for the admin password;
4. mint short-lived agent and backup tokens;
5. inject mapped secrets into the foreground gateway;
6. open the OpenClaw TUI.

Exit with `/exit`, Ctrl-D, or the documented Ctrl-C sequence. The launcher then
revokes tokens, takes an encrypted backup if configured, and stops its child
processes. If cleanup is interrupted, run `scripts/doctor` and inspect the
listener ports before starting again.

## Step 8: run the tests

The normal tests use a throwaway HOME and never contact real Vault:

```sh
make test
```

The E2E test also starts a disposable Vault and mock gateway. It does not use
your configured Vault or your real `secrets.map`. See
[`E2E.md`](E2E.md) for the detailed behavior:

```sh
tests/e2e/run.sh
```

The E2E harness allocates free loopback ports at runtime. On minimal Ubuntu
images it uses Python when `lsof`, `ss`, and `netstat` are unavailable. The
Ubuntu and macOS jobs therefore exercise the same lifecycle without requiring
fixed ports or host services.

## Step 9: configure encrypted backups

Backups are optional and disabled until configured. Follow
[`BACKUP-RESTORE.md`](BACKUP-RESTORE.md) to:

1. create an `age` identity outside the repository;
2. store the private identity in secure external custody;
3. put only the public recipient in the owner-only config directory;
4. set an approved absolute `BACKUP_DIR` in `stack.conf`;
5. run `scripts/backup` and verify the archive.

Never test restore against production data first. Inspect an archive with the
read-only default before using any restore flag.

## Step 10: connect continuous integration safely

If you enable CI on your preferred provider, run the same local checks in an
isolated job: shell linting, the dependency-light test suite, the disposable
E2E test, secret scanning, and release verification. Use short-lived job
identities or provider-managed secret storage when a job needs credentials.
Never commit tokens or place long-lived Vault credentials in repository files.
See [`CI-CD.md`](CI-CD.md) for the provider-neutral checklist.

## Step 11: update an existing installation

Use a published GitHub release tag, not `main`, as the update source. First exit
the work session and inspect available releases:

```sh
scripts/update --check
```

After reviewing the changelog and approving an exact tag, apply it:

```sh
scripts/update --to v1.0.1
```

The updater fetches tags, requires a clean checkout, refuses active listeners,
requires evidence of an encrypted backup, fast-forwards only, verifies
`VERSION` against the tag, and runs `doctor`. It updates wrapper code only: it
preserves XDG config/state, Vault data, workspace, memory, backups, and the
separately installed OpenClaw package. Review the result before starting:

```sh
scripts/work-session
```

For a new installation without backup evidence, the explicit escape hatch is:

```sh
scripts/update --to v1.0.1 --allow-no-backup
```

Use that only with deliberate operator approval. Automation may run
`scripts/update --check`, but must not apply updates from `main`, update an
active session, or silently bypass the backup guard.

## Automation checklist

An unattended wrapper may run these safe checks:

```sh
set -eu
make doctor
make check
make test
```

It must not automatically:

- initialize Vault or handle root/unseal material;
- enable a non-loopback listener;
- start a background service;
- write credentials to files or CI variables;
- run `scripts/uninstall --purge-data`;
- run `scripts/restore --restore` without a separate human approval.

## Common failures

| Symptom | Meaning | Next action |
| --- | --- | --- |
| `Vault is sealed` | Vault needs the threshold of unseal shares | Run `VAULT_ADDR=http://127.0.0.1:18200 vault operator unseal` interactively. |
| `permission denied` | The current token lacks the required policy | Use the approved operator login; do not add broad policy automatically. |
| `port is already in use` | Another process owns the configured listener | Inspect the port, stop only a process you own, then retry. |
| E2E says a port is not listening on Ubuntu | The test environment may lack common port tools | Confirm the checkout includes the Python socket fallback and rerun. |
| E2E says password file mode is invalid on Ubuntu | An older checkout used macOS-only `stat` flags | Update to the current checkout; the check now supports both `stat` variants. |
| `BACKUP_DIR is not set` | Backups are intentionally disabled | Configure backups or accept the warning for a test-only session. |

For deeper diagnosis, see [`OPERATIONS.md`](OPERATIONS.md),
[`SECURITY.md`](SECURITY.md), and [`ARCHITECTURE.md`](ARCHITECTURE.md).
