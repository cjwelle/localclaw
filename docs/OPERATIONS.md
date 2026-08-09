# Operations

Day-to-day running of the stack. Everything here is foreground and
operator-initiated — there is no unattended path.

## The mental model

A work session is a single foreground process tree that you own:

```text
open terminal ─► unseal Vault ─► mint agent token ─► inject secrets to gateway
      │                                                        │
   do work in the OpenClaw TUI (loopback) ◄────────────────────┘
      │
close TUI / Ctrl-C ─► revoke token ─► optional encrypted backup ─► stop Vault
```

Close the terminal and the session is over. There is nothing left running.

## Preflight (read-only)

Run before anything else. It changes nothing and exits non-zero on a critical
failure, so it is safe in CI too:

```sh
make doctor        # or scripts/doctor
```

It checks: OS + Bash, required tools, config presence, `BACKUP_DIR` safety, the
age recipient format, directory permissions, disk encryption (advisory), and —
if Vault happens to be running — its init/seal state (read-only probe).

## Starting Vault (foreground)

To inspect or operate Vault directly, start it in its own terminal:

```sh
make vault-start   # or scripts/vault-start ; stop with Ctrl-C
```

This clears any inherited Vault environment, pins `HOME` to an owner-only runtime
home (isolating token-helper state), and runs `vault server` in the foreground on
the loopback listener. In another terminal you can check status:

```sh
VAULT_ADDR="http://127.0.0.1:18200" vault status
```

> The helpers **refuse an inherited `VAULT_TOKEN`**. If you see that error, unset
> the variable so a token from another Vault cannot cross into this stack.

## First-time bootstrap (operator-driven)

This sequence is done **by you**, once. The tooling never sees your unseal or
recovery material.

1. Start Vault (`make vault-start`) in a dedicated terminal.
2. In another terminal, initialize it **yourself** and record the recovery
   material in your secret manager:

   ```sh
   VAULT_ADDR="http://127.0.0.1:18200" \
     vault operator init -key-shares=5 -key-threshold=3
   ```
3. Unseal with the threshold number of shares (hidden input):

   ```sh
   VAULT_ADDR="http://127.0.0.1:18200" vault operator unseal
   ```
4. Log in with the initial root token **only long enough** to:
   - enable the KV v2 mount (default name `local`),
   - write the three policies from `policies/`,
   - enable `userpass` and create your admin user with the `admin` policy,
   - create a token role that issues the least-privilege `agent` policy.
5. Verify your admin login and the agent role work, then **revoke the initial
   root token** and delete it from your secret manager. Keep your unseal shares.

Keep the mount name in `stack.conf` (`VAULT_KV_MOUNT`) in sync with the paths in
`policies/*.hcl`.

## A normal work session

With bootstrap done, start a session with `make work-session` (or
`scripts/work-session`). It:

1. Refuses to start if a conflicting listener holds the Vault or gateway port,
   or if a `VAULT_TOKEN` is inherited from another Vault.
2. Starts Vault as an owned child and prompts (hidden) for the unseal shares
   until it unseals, then for your admin password (read on stdin, never argv).
3. Mints two dedicated short-lived tokens via the Vault roles: an
   `agent-session` token (agent policy) and a `backup-session` token
   (snapshot-only backup policy).
4. Reads the mapped secrets (see `config/secrets.map`) with the admin token,
   drops the admin token, and injects **only** the agent token and those
   provider keys into the **foreground gateway's environment**.
5. Opens the OpenClaw TUI on loopback (TUI/chat only — no daemon or messaging).
6. On a clean exit, runs guarded cleanup **in order**: stop the gateway, take an
   encrypted backup with the backup token (while Vault is still unsealed), revoke
   both session tokens, stop Vault, and remove the temporary session logs.

```sh
scripts/work-session --dry-run       # validate only; starts/mints/reads nothing
scripts/work-session                 # a real foreground session
scripts/work-session --force-backup  # force an extra same-day backup on exit
```

> A forced kill (`kill -9`) or power loss **bypasses cleanup**, so it also
> bypasses the exit-time backup and token revocation. The next start re-checks
> state (it refuses conflicting listeners and a still-sealed Vault). Take an
> ad-hoc backup any time Vault is running and unsealed:

```sh
# During a session another terminal can also run, or run it standalone with a
# snapshot-capable token supplied out of band:
scripts/backup --dry-run    # validate BACKUP_DIR + recipient; touches no Vault
scripts/backup              # one snapshot (skipped if one already ran today)
scripts/backup --force      # snapshot even if one already ran today
```

See [`BACKUP-RESTORE.md`](BACKUP-RESTORE.md) for what an archive contains,
retention, and the restore procedure.

### Inspecting or restoring a backup

`scripts/restore` is **read-only by default** — it decrypts to an owner-only temp
dir, path-safety checks the archive before extracting, verifies `MANIFEST.txt`
and `SHA256SUMS`, and inspects the snapshot. It touches no live Vault and no live
config unless you opt in.

```sh
# Inspect only (default): validate + verify + snapshot inspect. Changes nothing.
scripts/restore --identity /path/to/backup.agekey  BACKUP.tar.gz.age

# Stage the archived non-secret config/policies somewhere for review:
scripts/restore --identity …/backup.agekey --stage-to "$HOME/openclaw-recovery" BACKUP.tar.gz.age

# DESTRUCTIVE: overwrite an isolated, unsealed local Vault's data (typed confirm):
LOCAL_VAULT_TOKEN=… scripts/restore --identity …/backup.agekey --restore BACKUP.tar.gz.age
```

The destructive restore requires a running, unsealed local Vault, a
`LOCAL_VAULT_TOKEN`, and typing the exact phrase `restore vault snapshot`. Adding
`--force` (a second `force overwrite` confirmation) bypasses Vault's
cluster/keyring match check and is appropriate **only** when restoring into a new
or empty cluster (e.g. a fresh laptop). Full details, including the staged and
opt-in `--restore-config` paths, are in
[`BACKUP-RESTORE.md`](BACKUP-RESTORE.md#restore-scriptsrestore--read-only-by-default).

### Exiting cleanly

- In the OpenClaw TUI: `/exit`, `Ctrl-D` on an empty input, or `Ctrl-C` twice
  within a second (a single `Ctrl-C` only shows the exit warning).
- At any launcher hidden prompt: `Ctrl-C` aborts and runs full cleanup.

## Working with memory

The SQLite work memory holds **summaries only**. At the start of a session where
you will read or write memory, run the purge (there is no scheduler):

```sh
DB="${XDG_STATE_HOME:-$HOME/.local/state}/openclaw-secure-local-stack/memory/work_memory.sqlite"
sqlite3 "$DB" < sql/purge_expired.sql
```

Record a one-line summary of notable actions in `action_log`; capture open items
in `follow_up`. Never store secrets. See [`../sql/README.md`](../sql/README.md).

## Removing a stale OpenClaw service

If a previous setup installed an OpenClaw gateway as a background service, remove
it so sessions are foreground-only. Check which profile actually owns the service
(it is not always the profile you expect):

```sh
openclaw gateway status
openclaw --profile work gateway status
```

Under whichever profile reports the installed service, stop and uninstall it:

```sh
openclaw [--profile <name>] gateway stop
openclaw [--profile <name>] gateway uninstall
```

This removes the service definition without deleting profile data. To restore an
automatic gateway later, re-run `gateway install` / `gateway start` under that
profile — but note that contradicts this stack's foreground-only model.

## Troubleshooting

| Symptom | Likely cause / fix |
| --- | --- |
| `Refusing inherited VAULT_TOKEN` | `unset VAULT_TOKEN` (and other `VAULT_*`) before using the stack. |
| `Vault is not running on port …` | Start it with `make vault-start`; check `VAULT_PORT` in `stack.conf`. |
| `port conflict` at session start | Another process holds the port; find it with `lsof -iTCP:<port> -sTCP:LISTEN`. |
| `Rendered Vault config not found` | Render `vault.hcl` (see `CONFIGURATION.md`) before starting Vault. |
| `BACKUP_DIR is unsafe or invalid` | Point it at an absolute, non-system folder outside the repo/state dir. |
| `database is locked` | Set `PRAGMA busy_timeout=5000` on your connection; avoid overlapping writers. |
| doctor `[WARN] FileVault appears Off` | Enable full-disk encryption before storing secrets. |
| Vault won't unseal after sleep | Expected: a sleep/wake time jump ends the session. Start a fresh one. |

## Uninstalling

`scripts/uninstall` removes only this project's **generated** config/tool files.
It is **plan-only by default** and preserves your data.

```sh
scripts/uninstall                 # plan only (default): show what it would remove
scripts/uninstall --apply         # remove generated config (typed UNINSTALL confirm)
scripts/uninstall --apply --purge-data   # ALSO delete runtime state (2nd confirm)
```

- **Removed** (under `--apply`, after typing `UNINSTALL`): the generated config
  directory (`stack.conf`, `secrets.map`, `vault.hcl`, `openclaw.json`, the
  public age-recipient file, the last-backup marker, and `*.bak.*`) and any
  repo-local rendered/backup leftovers.
- **Preserved by default:** the Vault Raft data, the SQLite work-memory DB, the
  runtime home, your **workspace**, and your **backup directory**.
- **Package managers and shared dependencies are never removed.** Uninstall
  prints the `brew`/`apt-get` commands for you to run yourself if you want to
  remove `vault`/`age`/`sqlite3`/etc.
- `--purge-data` additionally deletes local runtime state (Vault Raft data, the
  work-memory DB, runtime home, logs) and requires a **separate** typed
  `DELETE DATA` confirmation. It **refuses to run while a local Vault is
  listening** — this script never stops a process it did not start, so you stop
  the foreground Vault/`work-session` yourself first. Your workspace and backups
  are never deleted, even with `--purge-data`.

Take (and verify) a current backup before `--purge-data`.

## Routine checklist

See [`../workspace-template/HEARTBEAT.md`](../workspace-template/HEARTBEAT.md) for
a session start/during/end checklist. It is a human checklist — do **not** wire
it to a timer or scheduler.
