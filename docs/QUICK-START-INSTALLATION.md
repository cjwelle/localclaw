# Quick-Start Installation

> **Start here if you want the guided path:**
> this document covers the high-level install flow, installer behavior, and
> the supported prerequisites. For the low-level, command-by-command install
> sequence, recovery notes, and automation guardrails, use
> [`MANUAL-STEP-INSTALLATION.md`](MANUAL-STEP-INSTALLATION.md).

> **Official OpenClaw resources** (this repo is an independent hardening layer,
> not a fork): project <https://openclaw.ai/> · install docs
> <https://docs.openclaw.ai/install> · installer <https://openclaw.ai/install.sh>.
> Prefer the upstream docs for OpenClaw itself; always review any downloaded
> installer before running it (never curl-pipe into a shell).

## 1. Prerequisites

| Tool | Purpose | Required? |
| --- | --- | --- |
| `vault` | Local secrets engine (server + CLI) | Optional (required for Vault-backed sessions; the guided installer can install it) |
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

For the current validated version set, see the matrix in [`README.md`](../README.md).

### Password-manager prerequisites

Bitwarden is currently the only tested provider. The 1Password and LastPass
adapters are intended to work with their standard CLIs, but remain untested and
should be considered experimental until the project validates them.

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
   single key, not a password, unseal share, or mixed note.
6. A bootstrapped LocalClaw installation and at least one encrypted backup made with
   that matching public recipient. Run `./localclaw doctor` before setup.

The provider CLI may need network access on its first sign-in. Do not place
provider passwords, session tokens, age private identities, or Vault unseal
shares in `stack.conf`, Git, shell history, or command-line arguments. Follow
the detailed setup and verification procedure in
[`BACKUP-RESTORE.md`](BACKUP-RESTORE.md).

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
lifecycle test. See [`E2E.md`](E2E.md) for the disposable Vault details. It
does not apply a code update unless you explicitly pass `--apply-update`;
review the update check first. Use `--skip-tests` or `--skip-e2e` only when
you have a specific reason.

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

`./localclaw setup` is the guided first-run path. It starts by asking which
secret mode you want:

1. Vault only
2. Vault + password manager
3. Password-manager only

If you choose one of the password-manager modes, it then asks which provider
to use: Bitwarden, 1Password, or LastPass. Once LocalClaw is bootstrapped,
move to the upstream OpenClaw onboarding entry point in the official docs:
[`openclaw setup`](https://docs.openclaw.ai/cli/setup) for the interactive
flow, or [`openclaw setup --baseline`](https://docs.openclaw.ai/cli/setup) if
you only want to create the config/workspace folders first. Then continue with
[`docs/CONFIGURATION.md`](CONFIGURATION.md) and
[`docs/OPERATIONS.md`](OPERATIONS.md).

### Choose the session secret backend

LocalClaw supports three intentional configurations:

1. **Vault-only:** `SECRET_BACKEND=vault` and `CREDENTIAL_PROVIDER=none`.
   Vault is the local runtime secret store.
2. **Vault + password manager:** `SECRET_BACKEND=vault` with a configured
   provider. Vault still supplies runtime secrets; the provider can supply
   recovery shares or the encrypted-backup identity.
3. **Password-manager-only:** `SECRET_BACKEND=password-manager` with
   `CREDENTIAL_PROVIDER=bitwarden`, `1password`, or `lastpass`. Vault is not
   started. Values in `secrets.map` are retrieved just in time through the
   provider CLI and injected only into the foreground gateway.

The password-manager-only mode is an explicit tradeoff, not an automatic
fallback. It depends on the provider CLI and its authentication/session model.
Bitwarden is the only provider tested by this project; 1Password and LastPass
may work but remain experimental until validated.

Example setup commands:

```sh
./localclaw setup --secret-backend vault
./localclaw setup --secret-backend vault --password-manager bitwarden
./localclaw setup --secret-backend password-manager --password-manager bitwarden
```

After bootstrap, set the matching keys in `stack.conf`. In Vault mode,
`secrets.map` uses `ENV KV_PATH FIELD`; in password-manager mode it uses
`ENV PROVIDER_REFERENCE FIELD`, where the field is `password` or `notes` for
Bitwarden/LastPass. Use a complete `op://...` reference and `value` for
1Password.

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

> **Testing status:** Bitwarden is the only password-manager integration tested
> by the project so far. 1Password and LastPass are supported as future
> integration targets and may work now, but they have not yet been tested or
> validated by the project.

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

## Quick-Start: complete first installation

This is the canonical path from a clean OS to the first real LocalClaw
session. `./localclaw setup` handles software installation, local config
creation, doctor, regression tests, and a disposable E2E test. It does **not**
initialize or configure your real Vault; the remaining steps do that safely and
manually.

The distinction between the guides is simple:

- This Quick-Start guide is the recommended end-to-end sequence using
  `./localclaw`.
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

If you run `./localclaw setup`, the first prompt is the secret mode selector
and the provider question only appears when you choose a password-manager mode.

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

If you are following the flow manually, set `VAULT_ADDR` to the local listener
first, then run the standard Vault CLI command once per share:

```sh
export VAULT_ADDR="http://127.0.0.1:18200"
vault operator unseal
```

Optional: if you need to stop the foreground Vault from the second terminal,
use:

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

Once the admin login exists, keep `VAULT_ADDR` pointed at the local listener
and mint the short-lived least-privilege session tokens with the standard
Vault CLI token-create flow:

Use `export`, not `set`, so the address stays in scope for the later Vault
commands in the same shell.

```sh
export VAULT_ADDR="http://127.0.0.1:18200"
vault token create -role=agent-session -policy=agent -ttl=8h
vault token create -role=backup-session -policy=backup -ttl=8h
```

Those are the same roles the launcher uses later for the foreground gateway and
the backup path.

### 4. Add the secrets that OpenClaw should receive

Use the Vault CLI with an approved operator/admin token supplied interactively.
Set `VAULT_ADDR` first, then use the exact path that matches the mount/path/field
entries in `secrets.map`:

```sh
export VAULT_ADDR="http://127.0.0.1:18200"
vault kv put local/ai/openai api_key='PASTE_VALUE_INTERACTIVELY'
unset VAULT_ADDR VAULT_TOKEN
```

Do not paste real secrets into shell history, chat, Git, or `secrets.map`.

Optional: if you need to stop the foreground Vault from the second terminal
before step 5, use:

```sh
./localclaw vault-stop
```

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

If you want `scripts/work-session` to read the unseal shares automatically,
store them in a secure note in the password manager configured by
`CREDENTIAL_PROVIDER`, then set `VAULT_UNSEAL_REF` in `stack.conf` to that note
reference. For multiple LocalClaws, set `LOCALCLAW_PROJECT` and use a scoped
key like `ACME_VAULT_UNSEAL_REF` for that stack. Put one unseal share per line.
If `VAULT_UNSEAL_REF` and the project-scoped key are both unset, the launcher
prompts for the note reference at startup instead of falling back to manual
share entry.

If you are using a password manager, store the recovery material as separate
items so you do not paste the wrong value later:

- one entry for the **root token**;
- one entry for each **unseal share** (`unseal share 1`, `unseal share 2`,
  and so on);
- a clear label such as `LocalClaw Vault recovery`;
- a dedicated folder/vault if your provider supports one.

Do not combine the root token, unseal shares, backup identity, or unrelated
secrets in the same record.

> **Password-manager adapters.** The optional `localclaw credentials` workflow
> supports Bitwarden, 1Password, and LastPass for retrieving the private age
> identity during backup verification. It does not store provider passwords,
> session tokens, or unseal shares. See the step-by-step setup in
> [`BACKUP-RESTORE.md`](BACKUP-RESTORE.md).
