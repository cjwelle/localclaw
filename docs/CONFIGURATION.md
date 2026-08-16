# Configuration

> New installations should follow [`MANUAL-STEP-INSTALLATION.md`](MANUAL-STEP-INSTALLATION.md) first.
> This file is the reference for each non-secret setting and rendered file.

All configuration is **non-secret** and lives outside the repository, under your
XDG directories. Secret values never appear in any config file. They live in
Vault by default, or are retrieved just in time from the configured password
manager when `SECRET_BACKEND=password-manager` is selected.

## Where things live

| Purpose | Location |
| --- | --- |
| Editable config | `${XDG_CONFIG_HOME:-$HOME/.config}/localclaw/` |
| Runtime state | `${XDG_STATE_HOME:-$HOME/.local/state}/localclaw/` |
| Templates (in repo) | `config/*.example`, `config/*.template`, `config/*.sample` |

The config directory holds the rendered, editable files; the state directory
holds Vault's Raft data, the runtime home, logs, and the SQLite database. Both
are created `700` (owner-only). None of it is tracked by git.

## Files

### `stack.conf` (from `config/stack.conf.example`)

The single source of non-secret settings. Copy the example into your config
directory and edit it:

```sh
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/localclaw"
mkdir -p "$CFG" && chmod 700 "$CFG"
cp config/stack.conf.example "$CFG/stack.conf"
chmod 600 "$CFG/stack.conf"
$EDITOR "$CFG/stack.conf"
```

`stack.conf` is parsed as a restricted `KEY=VALUE` allow-list — it is **not**
sourced as shell, and unknown keys are ignored with a warning. Keys:

| Key | Default | Meaning |
| --- | --- | --- |
| `VAULT_HOST` | `127.0.0.1` | Listener address. **Keep it loopback.** |
| `VAULT_PORT` | `18200` | Vault API port. |
| `VAULT_CLUSTER_PORT` | `18201` | Vault cluster port (Raft). |
| `VAULT_NODE_ID` | `openclaw-local-1` | Raft node id. |
| `VAULT_KV_MOUNT` | `local` | KV v2 mount name. If you change it, update `policies/*.hcl`. |
| `OPENCLAW_PROFILE` | `work` | OpenClaw profile the gateway uses. |
| `OPENCLAW_PORT` | `18789` | Foreground gateway port (loopback). |
| `SECRET_BACKEND` | `vault` | `vault` for local Vault runtime secrets, or `password-manager` for direct provider retrieval. |
| `CREDENTIAL_PROVIDER` | `none` | `none`, `bitwarden`, `1password`, or `lastpass`. Required for password-manager backend. |
| `BACKUP_IDENTITY_REF` | _(empty)_ | Provider reference for the optional Vault backup identity; not required in password-manager-only mode. |
| `VAULT_BIN` / `OPENCLAW_BIN` / `AGE_BIN` / `AGE_KEYGEN_BIN` | names on `PATH` | Override with absolute paths if needed. |
| `VAULT_KEY_SHARES` / `VAULT_KEY_THRESHOLD` | `5` / `3` | Guidance only, used when *you* initialize Vault. |
| `BACKUP_DIR` | _(empty)_ | Absolute path to a folder you control. Empty disables backups. |
| `BACKUP_KEEP_DAILY` / `BACKUP_KEEP_WEEKLY` | `14` / `8` | Encrypted-archive retention counts. |
| `MEMORY_RETENTION` | `30 days` | Documented retention window for work memory. |

> **Loopback is a security boundary, not a preference.** TLS is disabled only
> because the listener never leaves `127.0.0.1`. Do not set `VAULT_HOST` to a
> routable address without enabling TLS and re-reading [`SECURITY.md`](SECURITY.md).

### `vault.hcl` (from `config/vault.hcl.template`)

The Vault server config. Placeholders of the form `@NAME@` are replaced with
values derived from `stack.conf` (host, ports, node id, and the owner-only Raft
data directory). The rendered file enables the UI, disables `mlock`, sets sane
lease TTLs, and keeps the listener loopback-only with `tls_disable = true`.

The renderer refuses to emit a file that still contains an unresolved `@NAME@`
token, so a misconfiguration fails loudly instead of producing a broken config.

### `openclaw.json` (from `config/openclaw.json.example`)

A **minimal, non-authoritative** config that selects local gateway mode,
loopback binding, the configured port, and the generated workspace. The
launcher exports `OPENCLAW_CONFIG_PATH` to this rendered file and
`OPENCLAW_STATE_DIR` to the project-owned state directory for both the gateway
and TUI. OpenClaw owns its schema and may change it between versions; after an
upgrade, validate the rendered file with `openclaw --profile work config
validate` using those same environment variables.

### `secrets.map` (from `config/secrets.map.sample`)

A whitespace-separated map of **environment variable → reference → field**.
It contains only names and references — never secret values. In the default
Vault mode, the reference is a KV path. In password-manager mode, it is a
provider-native item reference and the field is `password` or `notes` (or
`value` for a complete 1Password `op://` reference). Example Vault map:

```text
ANTHROPIC_API_KEY   ai/anthropic   api_key
OPENAI_API_KEY      ai/openai      api_key
```

At session start, the launcher reads each mapped field from Vault and injects it
into the **foreground gateway's environment only** — never to disk, logs, or
command-line arguments. In password-manager-only mode the same rule applies,
but the configured provider CLI supplies the value and Vault is not started.
Remove lines you do not use; if your OpenClaw build reads keys from its own
config, you may leave the file empty.

## Rendering the templates

`scripts/bootstrap` renders these for you (idempotently, owner-only). If you
render by hand instead, the important rules:

- Write every file with `umask 077` so it is created owner-only.
- Point the Raft `path` at a directory **inside your state dir**, not the repo.
- After rendering, run `make doctor` to confirm the files are found and the
  permissions are correct.

## Initializing work memory

Create the SQLite database from the schema (owner-only), then run the purge at
the start of any session where you will read or write memory:

```sh
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/localclaw"
DB="$STATE/memory/work_memory.sqlite"
mkdir -p "$(dirname "$DB")" && chmod 700 "$STATE" "$(dirname "$DB")"
( umask 077; sqlite3 "$DB" < sql/schema.sql )
sqlite3 "$DB" < sql/purge_expired.sql   # safe to run anytime; deletes expired rows
```

See [`../sql/README.md`](../sql/README.md) for what belongs in memory (summaries
only — never secrets) and notes on WAL and `busy_timeout`.

## Configuring backups

Backups are **off** until you set `BACKUP_DIR` to an absolute path you control
(a plain local folder or a cloud-sync folder). The stack refuses dangerous paths
(the filesystem root, system directories, your bare home directory, the repo,
and the runtime state directory) and writes **only** `age`-encrypted ciphertext
there. Full details, including generating the `age` identity, are in
[`BACKUP-RESTORE.md`](BACKUP-RESTORE.md).
