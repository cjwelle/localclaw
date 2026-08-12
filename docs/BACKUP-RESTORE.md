# Backup & Restore

## Password-manager key retrieval (Bitwarden, 1Password, or LastPass)

The encrypted backup recipient is public and stays in local configuration. The
private age identity is recovery material and should live in one password
manager. `osls backup verify` temporarily retrieves that identity, verifies the
archive with the existing read-only restore verifier, then removes the
temporary file. It does not restore Vault or replace configuration.

### Prerequisites checklist

Before configuring this workflow, confirm all of the following:

- A supported operating system: macOS or Ubuntu/Linux with Bash, a working
  network connection, and permission to install command-line tools.
- An active account with the provider you choose:
  [Bitwarden](https://bitwarden.com/), [1Password](https://1password.com/),
  or [LastPass](https://www.lastpass.com/). The account must be able to sign
  in and read the vault/item containing the backup identity.
- The provider's official CLI installed and available on `PATH`: `bw`, `op`,
  or `lpass`. The CLI must be compatible with the account and operating system.
- The provider's master password and any required MFA/security-key approval.
  The workflow cannot bypass provider authentication, account recovery, or
  organization policies.
- `age`, `age-keygen`, `tar`, `shasum` or `sha256sum`, and the local `vault`
  CLI installed. Run `./osls doctor` and fix required failures first.
- This repository bootstrapped with `./osls bootstrap`, so the owner-only
  `stack.conf` exists and can be updated. Do not configure this from a shared
  or world-writable account.
- One existing age key pair: the private identity stored in the provider, and
  its matching public recipient stored locally at
  `${XDG_CONFIG_HOME:-$HOME/.config}/openclaw-secure-local-stack/vault-backup-age-recipient`.
- At least one `*.tar.gz.age` backup created with that same public recipient.
  A newly configured provider cannot verify an archive encrypted to a
  different key.
- A secure provider record containing exactly one complete age private
  identity. Do not use a record that mixes multiple keys, passwords, unseal
  shares, or unrelated notes into the value returned by the CLI.

If the provider uses an organization-managed vault, the organization must
allow CLI access to the item and permit the account to read secure notes.
Offline-only provider access is insufficient for the first retrieval unless
the provider CLI already has a valid local session.

### 1. Create one secure record

Create a secure note in exactly one provider and paste the complete age private
identity into its Notes/secure-text body. Use a clear name such as `OSLS backup
identity`. Do not put the identity in Git, `stack.conf`, chat, or a normal text
file. Keep Vault root/unseal material in separate records.

### 2. Install the provider CLI

Install the official native CLI using its vendor documentation, then confirm
the command is on your `PATH`:

```sh
command -v bw       # Bitwarden
command -v op       # 1Password
command -v lpass    # LastPass
```

Use only one of these configuration commands. The reference is not the secret;
it is the provider-specific pointer to the secure note.

```sh
./osls credentials configure --provider bitwarden --ref 'OSLS backup identity'
./osls credentials configure --provider 1password --ref 'op://Private/OSLS-backup-identity/notes'
./osls credentials configure --provider lastpass --ref 'OSLS backup identity'
```

The command writes only `CREDENTIAL_PROVIDER` and `BACKUP_IDENTITY_REF` to
the owner-only local config. It never writes the private identity there.

### 3. Verify a backup

```sh
./osls credentials status
./osls backup verify /absolute/path/to/backup.tar.gz.age
```

Bitwarden and LastPass may prompt for their master password and MFA through
their own CLI. Do not pass those values as command-line arguments. The adapter
uses the native session briefly, removes the temporary age identity on success
or failure, and locks/logs out the provider session it opened. 1Password uses
the native `op read`/desktop-authentication flow and does not copy your
1Password password into this stack.

This workflow is intentionally limited to backup-key retrieval. Vault still
requires the configured unseal threshold, and the operator must enter those
shares manually during `scripts/work-session` or the documented bootstrap
procedure.

> New operators: start with [`SELF-HOSTING.md`](SELF-HOSTING.md), then return
> here for the detailed age identity, archive, verification, and restore steps.

Backups are **optional** and **off by default**. When enabled, the stack takes a
consistent Vault Raft snapshot and writes **only age-encrypted ciphertext** to a
directory you control. The private decryption key never lives in this repository.

> Restoring a snapshot is **destructive** and must be done deliberately, with an
> explicit typed confirmation, against an isolated local Vault. Read the whole
> page before restoring.

## What a backup contains

A single encrypted archive (`*.tar.gz.age`) holding:

- `vault/raft.snap` — a consistent Vault Raft snapshot (**treat as secret**),
- the rendered, **non-secret** stack config (`vault.hcl`, `stack.conf`,
  `openclaw.json` without secrets),
- the policies from `policies/`,
- `MANIFEST.txt` (versions, timestamps, snapshot checksum) and `SHA256SUMS`
  (a checksum for every staged file) for integrity verification on restore.

It never contains: unseal shares, recovery keys, the root token, API keys in
plaintext, the private `age` identity, the live Raft **data** directory, or the
session/runtime logs.

## The age identity

Backups use [age](https://age-encryption.org/) with an asymmetric identity:

- The **public recipient** (`age1...`) is what the stack encrypts *to*. It is not
  secret; a copy is referenced locally at
  `${XDG_CONFIG_HOME}/openclaw-secure-local-stack/vault-backup-age-recipient`.
- The **private identity** decrypts backups. It is a secret. **Generate it
  outside this repository and store it in your secret manager.** Do not commit
  it; `.gitignore` blocks `*.agekey` / `*age-identity*` as defense in depth.

Generate an identity yourself (example):

```sh
# Do this in a private, owner-only location — NOT inside the repo.
umask 077
age-keygen -o openclaw-vault-backup.agekey     # contains the PRIVATE key
# Extract the public recipient to reference locally:
age-keygen -y openclaw-vault-backup.agekey > \
  "${XDG_CONFIG_HOME:-$HOME/.config}/openclaw-secure-local-stack/vault-backup-age-recipient"
```

Then move `openclaw-vault-backup.agekey` into your secret manager and remove the
local copy. If you lose the public recipient file, re-derive it from the private
identity with `age-keygen -y`.

## Enabling backups

1. Set `BACKUP_DIR` in `stack.conf` to an **absolute path you control** (a plain
   local folder or a cloud-sync folder). The stack refuses the filesystem root,
   system directories, your bare home directory, the repository, and the runtime
   state directory.
2. Place the public recipient file as shown above.
3. Confirm with `make doctor` — it validates the path and the recipient format.

## When backups run

- Automatically during **guarded cleanup of a successfully opened interactive
  session** (`scripts/work-session`) — never on a schedule and never after a
  startup failure.
- The first successful session exit per local calendar day creates a backup;
  later exits that day skip it (the once-per-day guard) unless forced.
- Force an extra same-day snapshot after significant credential/policy/auth/Vault
  changes with `scripts/work-session --force-backup` (or `scripts/backup
  --force` against a running, unsealed Vault).
- A failed backup prints a warning and cleanup continues; a forced kill
  (`kill -9`) or power loss bypasses cleanup and therefore skips the backup and
  token revocation entirely.

You can also run the backup directly against a running, unsealed local Vault,
supplying a snapshot-capable token out of band:

```sh
scripts/backup --dry-run   # validate BACKUP_DIR + age recipient; touches no Vault
LOCAL_VAULT_TOKEN=… scripts/backup           # one snapshot (once-per-day guard)
LOCAL_VAULT_TOKEN=… scripts/backup --force   # snapshot even if one ran today
```

## How a backup is made (order matters)

1. `work-session` stops the foreground gateway first.
2. `scripts/backup` takes a consistent Raft snapshot using the **backup token**
   (snapshot-only policy; cannot read any KV secret) and inspects it.
3. It stages the snapshot with the non-secret config, policies, `MANIFEST.txt`,
   and `SHA256SUMS` in an **owner-only** temporary directory.
4. It streams `tar | age -R <recipient-file>` so the plaintext tarball is never
   written to disk — the only artifact is the ciphertext. If a verification
   identity is available (`BACKUP_VERIFY_IDENTITY`), it confirms the archive
   decrypts and lists.
5. It writes **only the ciphertext** into `BACKUP_DIR/Daily/` and
   `BACKUP_DIR/Weekly/` via atomic (`.partial` → rename) writes. There is no
   plaintext staging file in `BACKUP_DIR` and no copy of the live Raft data dir.
6. `work-session` then revokes the backup (and agent) tokens and stops Vault.

### Retention

Successful archives are kept as newest-N:

- `BACKUP_KEEP_DAILY` (default 14) daily archives in `Daily/`, and
- `BACKUP_KEEP_WEEKLY` (default 8) weekly archives in `Weekly/` (one stable
  archive per ISO week, refreshed by later same-week backups).

Pruning only ever removes files matching the encrypted-backup naming pattern
(`openclaw-vault-*.tar.gz.age` / `openclaw-vault-weekly-*.tar.gz.age`),
newest-first, and never touches unrelated files in the directory.

## Restore (`scripts/restore` — read-only by default)

`scripts/restore` is **safe by default**: with only an archive and your private
`age` identity it PLANS and INSPECTS. It never contacts a live Vault to change
it and never touches your live config or workspace unless you explicitly opt in.
The destructive snapshot restore runs only behind `--restore` **and** an exact
typed confirmation that names the action.

### Inspect an archive (default; changes nothing)

```sh
scripts/restore --identity /path/to/openclaw-vault-backup.agekey \
  /path/to/BACKUP_DIR/Daily/openclaw-vault-YYYYMMDDTHHMMSSZ.tar.gz.age
```

This will, in order:

1. Validate the archive path and the identity path (readable regular files).
2. Decrypt the archive into an **owner-only** (`700`) temporary directory. `age`
   reads the identity from a **file**, so no secret is ever placed on `argv`.
3. **Path-safety check the tar before extracting.** It refuses any member that
   is an absolute path, contains `..`, or is anything other than a plain file or
   directory (no symlinks, hardlinks, or device nodes). A backup this stack
   produced only ever contains regular files/dirs with simple `./…` names, so a
   rejection means the archive is not one to trust — it is **not** extracted.
4. Verify `MANIFEST.txt` (app + schema) and **every** checksum in `SHA256SUMS`,
   plus the snapshot checksum recorded in the manifest.
5. Run `vault operator raft snapshot inspect` on the recovered snapshot (this is
   read-only and needs no running Vault).

The owner-only temp directory is removed on exit (use `--keep-temp` to retain it
for debugging).

### Staged recovery of the non-secret config (optional)

To review the archived non-secret config/policies without touching your live
setup, copy them into a directory you choose. The `vault/raft.snap` is **not**
staged — the snapshot is only ever applied via `--restore`.

```sh
scripts/restore --identity …/backup.agekey \
  --stage-to "$HOME/openclaw-recovery" backup.tar.gz.age
```

### Opt-in restore of the live config (timestamped conflict backups)

`--restore-config` replaces your live `vault.hcl`, `stack.conf`, and
`openclaw.json` with the archived copies. It is **never** automatic: it requires
a typed `restore config files` confirmation, and each existing destination file
is preserved as a `…​.bak.<timestamp>` copy first. Your `secrets.map` is never
touched.

### The destructive snapshot restore (`--restore`)

Restoring **overwrites the target Vault's entire data set** and cannot be undone.
Do it only against an **isolated, loopback-only** local Vault you control.

1. Start an isolated local Vault and unseal it (see
   [`OPERATIONS.md`](OPERATIONS.md)). You initialize and unseal it — the stack
   never handles unseal/recovery material.
2. Supply a token permitted to restore snapshots out of band, and run:

   ```sh
   LOCAL_VAULT_TOKEN=… scripts/restore --identity …/backup.agekey \
     --restore backup.tar.gz.age
   ```

3. The script refuses an inherited `VAULT_TOKEN`, requires `LOCAL_VAULT_TOKEN`,
   requires a running **unsealed** local Vault, and then requires you to type the
   exact phrase **`restore vault snapshot`** before it proceeds. There is no
   silent restore.
4. Afterwards, verify with a read-only `vault status` and a spot check of
   expected mounts, then **rotate anything that could have been exposed** during
   recovery.

#### `--force` (bypass the cluster/keyring check) — when it is appropriate

By default the restore keeps Vault's cluster/keyring **match safety check**
enabled, so `snapshot restore` fails if the snapshot came from a different
cluster. That check is correct for the normal case: restoring into the *same*
local cluster the snapshot came from.

`--force` uses `snapshot restore -force`, which **bypasses** that check. It is
appropriate **only** when you are deliberately restoring into a **new or empty
cluster** whose autounseal/keyring cannot match the snapshot — for example a
fresh laptop rebuild where you initialized a brand-new Vault. Because it removes
a safety net, `--force` requires a **second** exact confirmation (`force
overwrite`) in addition to the first:

```sh
LOCAL_VAULT_TOKEN=… scripts/restore --identity …/backup.agekey \
  --restore --force backup.tar.gz.age
```

Do not use `--force` to paper over an unexpected mismatch when restoring into the
same cluster — investigate the mismatch instead.

## Verifying a backup without restoring

`scripts/restore --identity … <archive>` (with no `--restore`) is the supported
verification path: it decrypts, path-safety checks, and verifies all checksums
without touching a live Vault. As a quick manual check you can also decrypt and
list an archive directly:

```sh
age --decrypt --identity openclaw-vault-backup.agekey backup.tar.gz.age \
  | tar -tzf -
```

If either fails, the archive or the identity is wrong — do **not** rely on it for
recovery.

## New-laptop rebuild (overview)

A full disaster-recovery rebuild (planned `scripts/rebuild-laptop`) is manual by
design: install prerequisites yourself, authenticate to your cloud-sync and
secret manager interactively, and initialize a temporary empty Vault under your
control. Because a fresh laptop's Vault is a brand-new cluster, the destructive
step there is `scripts/restore --restore --force` (with both typed
confirmations); on the *same* machine's existing cluster, omit `--force`. It
never installs a service or scheduler.

## Uninstalling the stack

`scripts/uninstall` removes only this project's **generated** config/tool files
and is **plan-only by default**. It preserves your Vault data, the work-memory
database, your workspace, and your backup directory unless you explicitly opt in
to deleting local runtime state. See [`OPERATIONS.md`](OPERATIONS.md#uninstalling)
for the full procedure.
