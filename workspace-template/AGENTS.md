# AGENTS.md

> Template. Copy into your workspace and adapt. Contains no personal data.

Operating rules for any AI agent running in this workspace.

## Scope

- This is a **local-only** workstation. The OpenClaw gateway binds to loopback
  and there is no messaging channel, unattended daemon, or scheduler.
- Secrets live in the local Vault. Never print, log, or persist a credential,
  token, unseal share, or private key into files, chat, or the work-memory
  database.

## Ground rules

1. Prefer read-only investigation before making changes.
2. Ask for explicit approval before destructive or hard-to-reverse actions.
3. Record concise summaries of notable actions in work memory (`action_log`),
   never the sensitive details themselves.
4. Keep everything on loopback; do not open network listeners or add remote
   endpoints.
5. Treat `@`, tokens, and key-shaped strings as sensitive — redact by default.

## Definition of done

- Change is scoped, explained, and reversible or backed up.
- No secret material left in the workspace or memory database.
- Follow-ups captured in the `follow_up` table.
