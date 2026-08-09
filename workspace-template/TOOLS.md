# TOOLS.md

> Template. Describes tools available in this workspace. Adapt to your setup.

## Local stack

- **Vault (local, loopback):** secret storage at `http://127.0.0.1:<port>`.
  Access only through short-lived, session-scoped tokens. Never persist tokens.
- **Work memory (SQLite):** concise operational log. Summaries only, no secrets.
- **OpenClaw gateway/TUI:** foreground, loopback-only. Started via
  `scripts/work-session`.

## Conventions

- Read secrets from Vault at the moment of use; do not copy them into files.
- Log a one-line summary of significant actions to `action_log`.
- Prefer dry-run / plan modes of the stack scripts before applying changes.

## What NOT to do

- Do not add remote endpoints, schedulers, or background daemons.
- Do not write secrets to the workspace, shell history, or memory database.
