# CI/CD

This repository includes provider-neutral checks that can run locally or in
the CI platform of your choice. The goal is to make every check reproducible
without requiring access to private infrastructure.

## Recommended checks

Run these jobs for pull requests and release candidates:

| Check | Command | Purpose |
| --- | --- | --- |
| Shell syntax and executable bits | `tests/run.sh 00-syntax` | Detect broken scripts early. |
| Safety and rendering tests | `make test` | Exercise the throwaway-home test suite. |
| Ubuntu coverage | `scripts/ci-local ubuntu` | Run the suite in the documented Ubuntu container. |
| Native host coverage | `scripts/ci-local native` | Run the same suite on macOS or Linux. |
| End-to-end lifecycle | `tests/e2e/run.sh` | Verify disposable Vault, secret injection, gateway startup, and cleanup. |
| Secret scan | provider-native scanner or repository script | Reject credentials, state, and rendered runtime files. |
| Release verification | `scripts/release verify` | Validate the version and release metadata. |

The tests use throwaway directories and a disposable loopback Vault. They do
not use your real home directory, credentials, production Vault, or external
network services.

## Local CI helper

[`../scripts/ci-local`](../scripts/ci-local) keeps Docker operations explicit:

```sh
scripts/ci-local native        # native checks and linting
scripts/ci-local lint          # shellcheck only, when installed
scripts/ci-local pull          # explicitly pull the Ubuntu image
scripts/ci-local build         # explicitly build the test image
scripts/ci-local ubuntu        # run Ubuntu checks in the built image
scripts/ci-local all           # pull, build, and run Ubuntu checks
```

The Ubuntu run mounts the repository read-only and disables network access
after the image is available. macOS tests run natively because macOS cannot be
run in a Linux container.

## CI provider setup

For any CI provider, configure jobs equivalent to the checks above. Prefer
short-lived identity tokens and the provider's protected secret store. Never
commit credentials, place long-lived Vault tokens in repository variables, or
copy production secrets into an E2E job. The E2E job should create its own
throwaway Vault and use fixed, non-sensitive test values.

For optional E2E controls, use the `LOCALCLAW_E2E_` environment-variable prefix
(for example, `LOCALCLAW_E2E_PORT_BASE` or `LOCALCLAW_E2E_KEEP`). Older

Keep release jobs tag-gated and require all lint, test, security, and version
checks to pass before publishing an artifact. See [`VERSIONING.md`](VERSIONING.md)
for the canonical tag format.

## End-to-end behavior

`tests/e2e/run.sh` chooses free loopback ports, starts a temporary Vault, runs
the real `scripts/work-session`, verifies that a test secret reaches the mock
gateway, and confirms that child processes are stopped during cleanup. A
backup warning is expected when `BACKUP_DIR` is not configured; it does not
make the disposable E2E lifecycle fail.
