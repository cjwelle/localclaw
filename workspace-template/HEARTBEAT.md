# HEARTBEAT.md

> Template. There is NO unattended scheduler in this stack. "Heartbeat" here
> means a short, operator-initiated checklist at the start/end of a session.

## Session start

- [ ] Confirm you are on the intended machine and workspace.
- [ ] `scripts/doctor` reports green (or explains what is missing).
- [ ] Vault is running and unsealed for this session only.
- [ ] Run the work-memory purge if you are about to read/write memory.

## During the session

- [ ] Keep the gateway on loopback.
- [ ] Record notable actions as one-line summaries in `action_log`.

## Session end

- [ ] Exit the TUI so `work-session` runs guarded cleanup.
- [ ] Confirm the encrypted backup was written (or note the warning).
- [ ] Confirm Vault and the gateway are stopped.

This file is a human checklist, not an automation target. Do not wire it to a
timer, cron, or launchd/systemd unit.
