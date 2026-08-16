# Architecture

The stack is a small set of cooperating parts on a single machine. This page
describes the components, the session lifecycle, the secret-injection path, and
the backup flow using renderer-compatible Markdown.

## Components

| Area | Contents | Relationship |
| --- | --- | --- |
| Repository | Configuration templates, Vault policies, SQL schema, scripts, and workspace templates. | Contains no runtime secrets or state. |
| XDG config directory | `stack.conf`, rendered Vault/OpenClaw configuration, `secrets.map`, and the public age recipient. | Owner-only configuration used to start a session. |
| XDG state directory | Vault Raft data, Vault runtime home, work-memory SQLite database, and temporary logs. | Owner-only runtime state; never committed. |
| Local Vault | Loopback listener on `127.0.0.1`; TLS is disabled only because it never leaves the machine. | Stores secrets and issues short-lived session tokens. |
| OpenClaw gateway/TUI | Foreground, loopback-only process. | Receives mapped secrets through its environment. |
| `BACKUP_DIR` | Age-encrypted ciphertext archives only. | Receives optional Vault snapshots after encryption. |
| External secret manager | Unseal shares, root token, and private age identity. | Holds recovery material outside the repository and state directory. |

The operator supplies hidden prompts, applies policies, and controls external
secret custody. Vault injects secrets into the gateway environment only; the
gateway writes summaries, not secret values, to the memory database.

## Session lifecycle

The lifecycle is intentionally shown as a normal Markdown table instead of a
sequence diagram. This keeps the section readable in Markdown viewers that do
not support Mermaid sequence diagrams.

| Phase | Owner | Action | Security/lifecycle result |
| --- | --- | --- | --- |
| Start | Operator → `work-session` | Start the foreground session. | Conflicting listeners and services are refused. |
| Vault startup | `work-session` | Start the local Vault as an owned, loopback-only child. | Vault lifetime is tied to the session. |
| Unlock | Operator → Vault | Enter unseal shares and the admin password through hidden prompts. | Sensitive values are not written to the repository or logs. |
| Session credentials | `work-session` → Vault | Mint short-lived agent and backup tokens. | Tokens use separate least-privilege policies and exist only for the session. |
| Secret injection | `work-session` → Vault → gateway | Read paths listed in `secrets.map` and inject values into the gateway environment. | Secret values are kept out of files, logs, and the memory database. |
| Work | Operator → OpenClaw | Open the loopback-only gateway/TUI and do work. | The gateway runs in the foreground. |
| Exit | Operator → TUI | Exit with `/exit`, Ctrl-D, or double Ctrl-C. | The launcher begins shutdown and cleanup. |
| Backup | `work-session` → Vault → `BACKUP_DIR` | Optionally create a snapshot with the backup token and write an age-encrypted archive. | Only ciphertext leaves the live Vault; backup failure does not prevent shutdown. |
| Shutdown | `work-session` | Stop the gateway, revoke session and backup tokens, stop Vault, and remove temporary logs. | Owned child processes are cleaned up. |

Sleep, interruption, power loss, or a forced kill can bypass cleanup. Run the
doctor and backup verification checks after recovering from an unclean exit.

## Secret-injection path (least privilege)

| Step | Path | Allowed operation |
| --- | --- | --- |
| 1 | `local/ai/*` | The session token reads AI/service secrets allowed by policy. |
| 2 | `local/shared/*` | The session token reads shared values allowed by policy. |
| 3 | `local/agent/*` | The agent token may read/write its own small scratch values. |
| 4 | Gateway environment | `work-session` injects mapped values into the live process only. |
| 5 | Disk, logs, and database | Secret values are never written here. |

The `agent` policy can read AI/service and shared secrets and keep small values
under its own prefix — nothing else. Secrets flow into the live process
environment and are **never** persisted to disk, logs, or the memory database.

## Backup flow

| Step | Action | Result |
| --- | --- | --- |
| 1 | Session exits cleanly. | Backup processing begins; startup failures do not produce a backup. |
| 2 | Check for the first successful backup of the day. | Reuse the verified archive when one already exists. |
| 3 | Take a Vault snapshot with the backup token. | The backup token cannot read KV secrets. |
| 4 | Package the snapshot with non-secret configuration and policies. | A recovery package is prepared. |
| 5 | Encrypt the package to the public age recipient. | The private identity remains in external custody. |
| 6 | Verify decryption. | Warn and continue cleanup if verification fails. |
| 7 | Write ciphertext to `BACKUP_DIR`. | No plaintext backup leaves the live Vault. |
| 8 | Prune only matching archives and revoke the backup token. | Newest recovery points are retained and Vault stops. |

Startup failures never produce a backup. Only files matching the encrypted-backup
naming pattern are ever pruned, and the newest recovery point is never removed.

## Design principles reflected in the diagrams

- **One machine, loopback only.** No component listens on a routable address.
- **Foreground and owned.** The launcher owns Vault and the gateway as child
  processes; closing it tears them down.
- **Least privilege end to end.** Distinct policies for operator, agent, and
  backup; the backup path cannot read secrets, and the agent path cannot manage
  Vault.
- **Operator holds the crown jewels.** Unseal shares, root token, and the private
  `age` identity live in external custody, never in the repo or state dir.
- **Ciphertext leaves; plaintext never does.** The only external artifact is an
  age-encrypted archive.

See [`SECURITY.md`](SECURITY.md) for the controls behind these shapes and
[`OPERATIONS.md`](OPERATIONS.md) for how to drive them.
