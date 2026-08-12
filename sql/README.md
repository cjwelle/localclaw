# Work Memory (SQLite)

The stack keeps concise **operational memory** in a local SQLite database at:

```
${XDG_STATE_HOME:-$HOME/.local/state}/localclaw/memory/work_memory.sqlite
```

No live database file is committed to this repository. `scripts/bootstrap`
creates the database from [`schema.sql`](schema.sql) with owner-only
permissions.

## What belongs here

Short, non-sensitive summaries only:

- `action_log` — what happened, on which platform/environment, the outcome, and
  approval state.
- `follow_up` — open items to revisit.
- `settings` — key/value stack settings (e.g. retention policy).

**Never** store credentials, Vault tokens, unseal shares, private age
identities, API keys, or raw sensitive output. Secrets belong in Vault.

## WAL and busy_timeout

Two pragmas matter for an interactive, occasionally-concurrent session:

- `PRAGMA journal_mode = WAL;` — Write-Ahead Logging lets readers proceed while
  a writer is active and generally improves responsiveness. WAL is persistent
  once set on a database file, but it creates sidecar files
  (`work_memory.sqlite-wal`, `work_memory.sqlite-shm`) that must travel with the
  database if you ever copy it. Prefer running `PRAGMA wal_checkpoint(TRUNCATE);`
  before copying.
- `PRAGMA busy_timeout = 5000;` — wait up to 5s for a lock instead of failing
  immediately with `SQLITE_BUSY`. This is a **per-connection** setting, so set
  it on every connection. Both `schema.sql` and `purge_expired.sql` set it explicitly;
  set it yourself in any ad-hoc `sqlite3` session:

  ```sh
  sqlite3 "$DB" 'PRAGMA busy_timeout=5000; PRAGMA journal_mode=WAL; ...'
  ```

## Retention and purge

Rows carry a `retention_until` timestamp (default 30 days). Run the purge
during an active session — there is intentionally no scheduler:

```sh
sqlite3 "$DB" < sql/purge_expired.sql
```

`purge_expired.sql` uses `BEGIN IMMEDIATE` so the delete runs as one consistent
transaction.
