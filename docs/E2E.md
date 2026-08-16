# End-to-End Testing

`tests/e2e/run.sh` starts its **own throwaway Vault** in dev mode on a
loopback port it picks itself, seeded with a fixed, non-secret test password
and a fixed test API key. It never reads your `stack.conf` or `secrets.map`,
never talks to the Vault you initialized for a real install, and tears the
whole thing down - Vault process, mock gateway, temporary `HOME` - when it
exits.

That makes the E2E test safe to run at any time, on any machine, including in
CI.

## Related

- [`CI-CD.md`](CI-CD.md) for the broader provider-neutral CI checklist.
- [`QUICKSTARTINSTALLATION.md`](QUICKSTARTINSTALLATION.md) for the guided local installation flow.
