# admin.hcl - administrator policy for the local OpenClaw stack.
#
# Granted to the interactive human operator (via userpass) so they can manage
# the KV mount, policies, auth methods, token roles, and take Raft snapshots.
# This is NOT a root policy: it cannot manage the seal, storage internals, or
# arbitrary system backends beyond what is listed here.
#
# NOTE: paths assume the KV v2 mount is named "local" (VAULT_KV_MOUNT default).
# If you change the mount name, update every "local/..." path below to match.

path "local/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}

path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/audit" {
  capabilities = ["read", "sudo"]
}

path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "auth/token/roles/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "auth/token/create/*" {
  capabilities = ["create", "update", "sudo"]
}

path "auth/userpass/users/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/health" {
  capabilities = ["read", "sudo"]
}

path "sys/storage/raft/snapshot" {
  capabilities = ["read", "sudo"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}
