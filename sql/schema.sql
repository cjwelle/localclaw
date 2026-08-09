-- openclaw-secure-local-stack - work-memory schema.
--
-- This database stores concise OPERATIONAL SUMMARIES only. Never store
-- credentials, tokens, unseal shares, private keys, secrets, or raw
-- sensitive command output here.
--
-- Applied by scripts/bootstrap against:
--   ${XDG_STATE_HOME}/openclaw-secure-local-stack/memory/work_memory.sqlite
-- No live database file ships in this repository.

-- WAL improves read/write concurrency for an interactive session; the
-- busy_timeout avoids spurious "database is locked" errors when a short
-- write overlaps a read. Both are connection-level pragmas and are set by
-- the client on every connection (see sql/README.md).
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;

CREATE TABLE IF NOT EXISTS settings (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS action_log (
    id              INTEGER PRIMARY KEY,
    occurred_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    platform        TEXT NOT NULL,
    environment     TEXT NOT NULL,
    action_type     TEXT NOT NULL,
    summary         TEXT NOT NULL,
    outcome         TEXT NOT NULL,
    approval_status TEXT NOT NULL CHECK (
        approval_status IN ('not-required', 'requested', 'approved', 'denied')
    ),
    approval_reference TEXT,
    retention_until TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now', '+30 days'))
);

CREATE INDEX IF NOT EXISTS idx_action_log_retention
    ON action_log (retention_until);

CREATE TABLE IF NOT EXISTS follow_up (
    id          INTEGER PRIMARY KEY,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    summary     TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'done', 'cancelled')),
    retention_until TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now', '+30 days'))
);

CREATE INDEX IF NOT EXISTS idx_follow_up_retention
    ON follow_up (retention_until);

INSERT INTO settings (key, value)
VALUES ('retention_policy', '30 days')
ON CONFLICT(key) DO NOTHING;

INSERT INTO settings (key, value)
VALUES ('schema_version', '1')
ON CONFLICT(key) DO NOTHING;
