# agent.hcl - least-privilege policy for the foreground OpenClaw agent.
#
# The short-lived token minted for each work session carries only this policy.
# It can read the AI/service secrets the gateway needs and keep small
# operational values under its own prefix -- nothing else. It cannot manage
# policies, auth methods, mounts, or take snapshots.
#
# NOTE: paths assume the KV v2 mount is named "local" (VAULT_KV_MOUNT default).

path "sys/health" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

# The gateway's own scratch area (e.g. rotated per-agent operational values).
path "local/data/agent/*" {
  capabilities = ["create", "read", "update", "patch", "list"]
}
path "local/metadata/agent/*" {
  capabilities = ["read", "list"]
}

# AI provider / service credentials: read-only.
path "local/data/ai/*" {
  capabilities = ["read", "list"]
}
path "local/metadata/ai/*" {
  capabilities = ["read", "list"]
}

# Shared read-only secrets available to the agent.
path "local/data/shared/*" {
  capabilities = ["read", "list"]
}
path "local/metadata/shared/*" {
  capabilities = ["read", "list"]
}
