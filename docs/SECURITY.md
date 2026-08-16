# Security Model

This document describes how the running stack protects secrets. For how to
**report** a vulnerability, see the top-level [`../SECURITY.md`](../SECURITY.md).

## Design goals

1. Compromise or misbehavior of the AI agent must not leak long-lived
   credentials or reach the network.
2. A closed terminal is a closed session: no unattended state, no lingering
   tokens, no background process.
3. The operator — not the tooling — always controls the most sensitive
   material (unseal shares, recovery keys, root token, private backup key).

## Trust boundary

```text
        ┌─────────────────────────── your machine (full-disk encrypted) ───────────────────────────┐
        │                                                                                           │
        │   operator (you) ──hidden prompts──►  work-session launcher (foreground, owns children)   │
        │        │                                     │                                            │
        │        │ holds: unseal shares,               │ mints: short-lived least-privilege token   │
        │        │ recovery keys, root token,          ▼                                            │
        │        │ private age identity          local Vault (127.0.0.1, Raft, TLS-off loopback)    │
        │        │                                     │                                            │
        │        ▼                                     ▼                                            │
        │  external custody                     OpenClaw gateway + TUI (127.0.0.1) ── agent policy   │
        │  (password/secret manager)                                                                │
        └───────────────────────────────────────────────────────────────────────────────────────────┘
                                   ▲                                   │
                                   │ age-encrypted ciphertext only     │ no inbound network,
                                   └─ backup dir (local / cloud-sync) ◄┘ no messaging channel
```

Everything runs on one machine behind full-disk encryption. Nothing in the trust
boundary listens on a routable address. The only data that leaves the machine is
**age-encrypted ciphertext** to a backup directory you choose.

## Controls

### Loopback only, no messaging channels
- Vault's listener and the OpenClaw gateway bind to `127.0.0.1`.
- TLS is disabled **only** because the listener never leaves localhost. Changing
  the address to anything routable **requires enabling TLS first** and is called
  out in `config/vault.hcl.template` and `config/stack.conf.example`.
- There are no inbound webhooks, chat bridges, or remote-control endpoints.

### No daemons or schedulers by default
- Vault runs in the foreground (`scripts/vault-start` / the session launcher) and
  is attached to your terminal. Ctrl-C stops it.
- No launchd agent, systemd unit, cron job, or timer is installed. If your OS
  package created a Vault service, [`QuickStartInstall.md`](QuickStartInstall.md) tells you to disable
  it.
- Backups happen only during guarded cleanup of a real interactive session —
  there is no scheduler.

### Operator-controlled initialization
- **You** run `vault operator init`, choose the share/threshold parameters, and
  place recovery material in an external custody system (a password/secret
  manager). The stack must never view its output, enter unseal material, or
  handle the initial root token.
- After you initialize and unseal, you apply the policies and create the KV v2
  mount and auth role. Only then does the automated session flow become usable.

### Least-privilege tokens
Three policies, one per role (see [`../policies/`](../policies/)):

| Policy | Who | Can | Cannot |
| --- | --- | --- | --- |
| `admin.hcl` | Human operator (userpass) | Manage the KV mount, policies, auth methods, token roles; take snapshots | Manage the seal, storage internals, or arbitrary system backends |
| `agent.hcl` | Foreground gateway token | Read AI/service + shared secrets; keep small values under its own `agent/` prefix | Manage policies/auth/mounts; take snapshots; read other prefixes |
| `backup.hcl` | Session-exit backup token | Take a Raft snapshot; manage its own lifecycle | Read **any** KV secret |

The agent and backup session tokens are short-lived orphan tokens. This lets the
launcher revoke its temporary administrator login before the gateway starts
without invalidating the session. Both least-privilege tokens are revoked on
exit.

### Token hygiene
- The helper library **refuses an inherited `VAULT_TOKEN`** so a corporate/other
  Vault token can never cross into this stack.
- The local session token is supplied transiently through an environment
  variable for a single command — never as a CLI argument (which would land in
  `ps`/shell history) and never written to a file.
- Persistent CLI token storage is neutralized by pinning `HOME` to an
  owner-only runtime home, isolating token-helper state from any other Vault
  configuration.
- Inherited `VAULT_ADDR`, `VAULT_NAMESPACE`, and TLS env vars are reset so the
  CLI can only talk to the local instance.

### Secrets never touch disk in cleartext
- Secrets are read from Vault at the moment of use and injected into the
  **foreground gateway's environment only**. They are not written to workspace
  files, the SQLite database, logs, or command lines.
- The work-memory database stores **operational summaries only**. The schema and
  docs prohibit credentials, tokens, unseal shares, private keys, and raw
  sensitive output.

### Owner-only directories
- Config and state directories are created `700`; sensitive files `600`. Rendered
  files are written with `umask 077`. `scripts/doctor` verifies this.

### Encrypted backups, private key off-repo
- Backups are optional and contain a Vault Raft snapshot plus non-secret config.
  They are encrypted with **age** to a public recipient. The **private identity
  is generated outside the repository** and stored in your own secret manager;
  only the public recipient is referenced locally.
- The stack writes **only ciphertext** to the backup directory — never a
  plaintext staging copy and never a direct copy of the live Raft data dir.
- Restore (`scripts/restore`) is **read-only by default**: it decrypts into an
  owner-only temp dir, **path-safety checks the archive before extracting**
  (refusing absolute paths, `..`, and any non-regular-file member such as a
  symlink), and verifies `MANIFEST.txt`/`SHA256SUMS` before it will inspect the
  snapshot. `age` reads the identity from a **file**, so no secret is placed on
  `argv`. The destructive `operator raft snapshot restore` runs only behind an
  exact typed confirmation while the target Vault is isolated; `-force` is never
  used unless separately confirmed. It never overwrites your live config or
  workspace automatically. See [`BACKUP-RESTORE.md`](BACKUP-RESTORE.md).

### Safe uninstall
- `scripts/uninstall` is **plan-only by default** and removes only
  project-**generated** config/tool files. It refuses unsafe roots, requires a
  typed confirmation, and **preserves Vault data, the work-memory DB, your
  workspace, and your backups**. Deleting local runtime state needs a separate
  flag and a second typed confirmation. It never removes package managers or
  shared dependencies, and **never stops a process it did not start** (it refuses
  to purge data while a local Vault is running).

### Sleep/interruption ends the session
- A laptop sleep/wake time jump, closing the launcher, or interrupting it ends
  the session rather than resuming an unsealed Vault unattended. Cleanup revokes
  the token and stops Vault. A forced kill or power loss can bypass cleanup —
  the next start re-checks state.

## Threats considered / not considered

**Mitigated:** credential exfiltration by the agent to disk or network; token
reuse after a session; accidental exposure of a corporate Vault token;
world-readable config/state; plaintext backups; unattended running Vault.

**Not in scope:** a compromised operating system, kernel, or full-disk-encryption
bypass; a malicious `vault`/`openclaw`/`age` binary; physical access to an
unlocked, unsealed machine; supply-chain compromise of upstream tools. Keep your
OS patched and your disk encrypted.

## Non-goals (by design)

- No unattended or scheduled operation.
- No messaging channels or remote control.
- No non-loopback listener without TLS.
- No storage of unseal/recovery/root material or the private `age` key by the
  tooling.

## Security support and versions

Reporting instructions, the supported-versions table, and response expectations
live in the top-level [`../SECURITY.md`](../SECURITY.md). In summary:

- Support tracks **published release lines** only; a line is listed as supported
  **once it is actually released**. This project is at `0.1.0`, so **`0.1.x` is
  supported**; earlier/unreleased versions are not. Illustrative future lines
  such as `1.5.x`, `2.0.x`, or `2.5.x` appear only after they ship.
- Expect an **initial acknowledgement within 1–2 weeks** of a report.
- `VERSION` is canonical and follows SemVer — see
  [`VERSIONING.md`](VERSIONING.md). Releases are tag-gated and run the full test
  matrix (Ubuntu + native macOS) before publishing — see [`CI-CD.md`](CI-CD.md).

The project maintainer and security contact is **Christopher Welle**
&lt;cjwelle@gmail.com&gt;.

## Operator responsibilities

- Keep full-disk encryption **on**.
- Custody unseal shares, recovery keys, and the private `age` identity in an
  external secret manager — never in this repo, chat, or the database.
- Review policy changes; keep the mount name and policy paths in sync.
- Revoke the initial root token after bootstrapping an admin login, and keep
  your unseal shares.
