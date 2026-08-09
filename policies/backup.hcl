# backup.hcl - least-privilege policy for the session-exit backup token.
#
# The dedicated backup token carries only this policy: it can take a Raft
# snapshot and manage its own lifecycle. It cannot read any KV secret.

path "sys/health" {
  capabilities = ["read"]
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
