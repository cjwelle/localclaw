# Architecture

The stack is a small set of cooperating parts on a single machine. This page
describes the components, the session lifecycle, the secret-injection path, and
the backup flow, with Mermaid diagrams.

## Components

```mermaid
flowchart TB
    subgraph Machine["Your machine (full-disk encrypted)"]
        direction TB
        Operator([Operator])

        subgraph Repo["Repository (no secrets, no state)"]
            Templates["config/*.example / *.template"]
            Policies["policies/*.hcl"]
            Schema["sql/schema.sql"]
            Scripts["scripts/ (work-session, backup, vault-start, doctor, lib)"]
            WsTmpl["workspace-template/"]
        end

        subgraph Config["XDG config dir (700)"]
            StackConf["stack.conf"]
            VaultHcl["vault.hcl (rendered)"]
            OpenclawJson["openclaw.json (rendered)"]
            SecretsMap["secrets.map (names only)"]
            AgeRecip["age recipient (public)"]
        end

        subgraph State["XDG state dir (700)"]
            Raft[("Vault Raft data")]
            RuntimeHome["vault runtime HOME"]
            MemDb[("work_memory.sqlite")]
            Logs["temp logs"]
        end

        Vault["Local Vault<br/>127.0.0.1:18200 (loopback, TLS off)"]
        Gateway["OpenClaw gateway + TUI<br/>127.0.0.1 (loopback)"]
    end

    BackupDir[("BACKUP_DIR<br/>age ciphertext only")]
    Custody[["External secret manager<br/>(unseal shares, root token,<br/>private age identity)"]]

    Operator -->|hidden prompts| Vault
    Operator -->|custody| Custody
    Templates -.render.-> VaultHcl
    Policies -.applied by operator.-> Vault
    Schema -.init.-> MemDb
    Vault --- Raft
    Vault --- RuntimeHome
    SecretsMap -.maps env→path.-> Gateway
    Vault -->|inject to env only| Gateway
    Gateway -.summaries only.-> MemDb
    Vault -->|snapshot| BackupDir
    AgeRecip -.encrypt to.-> BackupDir
    Custody -.decrypt.-> BackupDir
```

## Session lifecycle

```mermaid
sequenceDiagram
    autonumber
    actor Op as Operator
    participant L as work-session (foreground)
    participant V as Local Vault (loopback)
    participant G as OpenClaw gateway/TUI
    participant B as BACKUP_DIR

    Op->>L: start session
    L->>L: refuse conflicting service/listener
    L->>V: start Vault as owned child
    Op-->>V: unseal shares + admin password (hidden)
    L->>V: mint short-lived token (agent policy)
    V-->>L: session token (env only)
    L->>V: read mapped secrets (secrets.map)
    V-->>L: secret values
    L->>G: inject secrets into gateway ENV only
    L->>G: open TUI (loopback)
    Op->>G: do work
    Op->>G: /exit (or Ctrl-D / double Ctrl-C)
    G-->>L: TUI closed
    L->>G: stop gateway
    L->>V: (optional) snapshot via backup token
    L->>B: write age-encrypted archive
    L->>V: revoke session + backup tokens
    L->>V: stop Vault
    L->>L: remove temp logs
    Note over Op,B: Sleep/interrupt/power-loss ends the session;<br/>a forced kill can bypass cleanup.
```

## Secret-injection path (least privilege)

```mermaid
flowchart LR
    subgraph VaultKV["Vault KV v2 (mount: local)"]
        AI["local/ai/*"]
        Shared["local/shared/*"]
        AgentP["local/agent/* (scratch)"]
    end

    Token["Session token<br/>policy: agent.hcl"]
    Env["Gateway process ENV<br/>(foreground only)"]
    Disk[["Disk / logs / DB"]]

    AI -->|read| Token
    Shared -->|read| Token
    Token <-->|read/write| AgentP
    Token -->|inject| Env
    Env -. never written .-> Disk

    classDef forbid stroke-dasharray: 4 4;
    class Disk forbid;
```

The `agent` policy can read AI/service and shared secrets and keep small values
under its own prefix — nothing else. Secrets flow into the live process
environment and are **never** persisted to disk, logs, or the memory database.

## Backup flow

```mermaid
flowchart TD
    Start(["Interactive session exits cleanly"]) --> First{"First success<br/>today?"}
    First -- no --> Reuse["Reuse verified archive"] --> Done
    First -- yes --> Snap["Snapshot via backup token<br/>(cannot read secrets)"]
    Snap --> Pkg["Package snapshot + non-secret config + policies"]
    Pkg --> Enc["Encrypt to age public recipient"]
    Enc --> Verify{"Decrypts with<br/>identity?"}
    Verify -- no --> Warn["Warn; continue cleanup"] --> Done
    Verify -- yes --> Write["Write CIPHERTEXT ONLY to BACKUP_DIR"]
    Write --> Prune["Prune: keep newest N daily / weekly"]
    Prune --> Done(["Revoke backup token; stop Vault"])
```

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
