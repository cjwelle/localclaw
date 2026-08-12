# CI/CD

> New operators should read [`SELF-HOSTING.md`](SELF-HOSTING.md) first. This
> document is the CI reference; [`GITLAB-SETUP.md`](GITLAB-SETUP.md) is the
> runner-registration runbook.

This project ships a GitLab pipeline ([`../.gitlab-ci.yml`](../.gitlab-ci.yml))
and a local mirror ([`../scripts/ci-local`](../scripts/ci-local)) so the same
checks run on your machine and in CI. Everything is designed to run on an
**internal GitLab with only the free tier** — no paid services, no privileged
containers, no service daemons, and no container registry required.

For copy-ready project creation and runner registration commands, see
[`GITLAB-SETUP.md`](GITLAB-SETUP.md).

## What runs

| Stage | Job | What it does |
| --- | --- | --- |
| lint | `lint:shellcheck` | `make check` → `shellcheck -x` over every shipped script. |
| test | `test:ubuntu` | Runs `tests/run.sh` in an `ubuntu:latest` container. |
| test | `test:macos` | Runs the **same** `tests/run.sh` natively on a macOS shell runner. |
| test | `e2e:ubuntu` | Scheduled/manual disposable Ubuntu lifecycle test, including Vault secret injection and cleanup. |
| test | `e2e:macos` | Scheduled/manual native macOS lifecycle test on the shell runner. |
| security | `secret-scan` | Self-contained scan for forbidden artifacts and secret-shaped content. |
| security | `secret-scan:gitleaks` | Optional, pinned gitleaks scan (off by default). |
| version | `version:verify` | `scripts/release verify` — SemVer format, and tag match on tags. |
| package | `package` | Builds `dist/…tar.gz` + `SHA256SUMS` (proves packaging works). |
| release | `release:artifacts` | **Tag-only.** Rebuilds the artifact + checksums after all gates pass. |

The container jobs install their handful of tools inline from the Ubuntu
archive (`bash`, `coreutils`, `git`, `jq`, `sqlite3`, `age`, `tar`, …), so the
pipeline needs **no prebuilt image and no registry**. If you prefer a prebaked
image, [`../docker/Dockerfile.ci`](../docker/Dockerfile.ci) builds one; publish
it and point the jobs at it.

## The Ubuntu test image

[`../docker/Dockerfile.ci`](../docker/Dockerfile.ci) is based on `ubuntu:latest`,
installs only the test/lint tools, runs as a **non-root** user, and starts no
services. It COPYs nothing in — the repository is bind-mounted at run time (CI
mounts it; `scripts/ci-local` mounts it **read-only**). Rebuild it only when the
tool set changes.

## macOS: why there is no macOS container

**Docker cannot run macOS.** Apple's licensing and the kernel/userland mean
there is no legitimate macOS container base image, and this project will not fake
one. macOS is a first-class target for the stack (the scripts target Bash 3.2,
the stock macOS shell), so we cover it by running the identical suite **natively
on a real Mac**:

- **In CI:** register a GitLab runner with the **`shell` executor** on a macOS
  host and give it the tag **`macos`**. The `test:macos` job targets that tag.
  Without such a runner, `test:macos` cannot run — and because a release depends
  on it, you cannot cut a release without a Mac in the loop. That is intentional.
- **Locally:** run `scripts/ci-local native` on your current Mac (or any host).

This split — Ubuntu in a container, macOS on a native shell runner — is the whole
reason the pipeline never pretends a single image covers both operating systems.

## Running it locally: `scripts/ci-local`

`scripts/ci-local` performs **no Docker action implicitly**. Pulling and building
are explicit subcommands, so running the native tests never touches the network
or the Docker daemon.

```sh
scripts/ci-local native        # run the suite on THIS host (macOS or Linux) + lint
scripts/ci-local lint          # shellcheck only (if installed)
scripts/ci-local pull          # docker pull ubuntu:latest        (explicit)
scripts/ci-local build         # docker build the CI image        (explicit)
scripts/ci-local ubuntu        # run the suite inside the built image (repo mounted read-only)
scripts/ci-local all           # pull + build + ubuntu
scripts/ci-local native -- -v  # pass extra args to tests/run.sh (verbose)
```

The `ubuntu` run mounts the repo **read-only** and uses `--network none`: the
suite writes only to a throwaway `HOME` under the container's `/tmp` and never
needs the network.

## The test-suite

[`../tests/run.sh`](../tests/run.sh) is dependency-light and Bash-3.2-safe. It
creates a **throwaway sandbox `HOME`** per case and refuses to run if it cannot
get a private temp directory — it never uses your real `HOME`, real credentials,
a real Vault, or the network. Cases degrade gracefully (`skip`) when an optional
tool (`age`, `sqlite3`, `jq`) is absent, so the same suite passes on a bare
container and on a Mac. Coverage:

- `00-syntax` — `bash -n` for every script + executable bits.
- `10-dry-run-safety` — plan/dry-run modes change nothing under a temp HOME.
- `20-bootstrap-render` — rendering, permissions, and byte-for-byte idempotency.
- `30-path-safety` — `validate_safe_dir`/`validate_backup_dir` refuse dangerous paths.
- `40-backup-retention` — synthetic `prune_to_count` keeps newest N, touches nothing else.
- `50-restore-defenses` — traversal, symlink, checksum, MANIFEST, and identity refusals.
- `60-uninstall-preservation` — plan vs `--apply` vs `--purge-data` preserve data.
- `70-config-validation` — templates/policies/ports/mount are internally consistent.
- `80-docs-links` — every relative Markdown link resolves.
- `90-no-secret-artifacts` — no secrets/state/rendered config in the tree.
- `95-release-versioning` — `scripts/release` SemVer + tag gating, never runs git.

Run a subset by name fragment: `tests/run.sh 50-restore 95-release`.

## End-to-end tests and Vault

The E2E jobs run `tests/e2e/run.sh`. Each job creates a temporary loopback Vault,
starts the real `scripts/work-session` through a pseudo-terminal, verifies that
a test secret reaches the gateway, and verifies that Vault and the gateway ports
are closed during cleanup. No production Vault data is used by the harness.

The harness deliberately avoids fixed ports. It asks Python for three free
loopback ports and writes those values into the temporary `stack.conf`. The
shared shell helper detects listeners with `lsof`, `ss`, or `netstat` when
available and falls back to a Python TCP connect probe on minimal Ubuntu
images. The E2E-only password-file permission check also uses the platform's
available `stat` syntax. These details prevent a Linux container from being
mistakenly reported as a Vault failure when Vault actually started correctly.

That temporary Vault is **not** the same thing as the Vault a user sets up
locally with `scripts/vault-bootstrap` (see the Quick Start in
[`INSTALL.md`](INSTALL.md)). This section is about a second, separate Vault —
one that the project maintainer operates — that exists only to hand the CI
job one disposable test API key before the job starts its own throwaway Vault.
No contributor needs credentials for it; it is used only by the two `e2e:*`
jobs, and only for the duration of the job.

### How the CI job authenticates to that Vault (OIDC, no stored secret)

Rather than storing a long-lived Vault token as a GitLab CI/CD variable, the
`e2e:*` jobs use GitLab's **OIDC (OpenID Connect) identity federation**, at a
high level:

1. GitLab mints a short-lived, **project-scoped ID token** for the job (the
   `id_tokens: VAULT_ID_TOKEN` block in `.gitlab-ci.yml`) — a signed JWT that
   asserts facts like "this is a specific job, in this specific project, on
   this specific ref," signed by GitLab's own OIDC issuer.
2. The job's `before_script` presents that JWT to Vault's `auth/jwt/login`
   endpoint (`vault write ... auth/jwt/login role=gitlab-localclaw-test jwt="$VAULT_ID_TOKEN"`),
   requesting a specific Vault role.
3. Vault's JWT auth method — configured by the Vault operator, not by
   anything in this repo — is set up ahead of time to trust GitLab's OIDC
   issuer and to bind that role to this exact project (`project_id=62`) with
   a short token TTL. Vault only issues a token back if the JWT's claims
   match what the role expects.
4. The job uses the short-lived Vault token it gets back to read exactly one
   field, `test_api_key`, from one path (`zivo/gitlab/test`), then
   immediately `unset`s the token variable.
5. That value is exported as `OSLS_E2E_EXPECTED_API_KEY` and handed, in
   memory, to the disposable dev-mode Vault that `tests/e2e/run.sh` starts —
   never written to the repository, a file, or CI logs.

No static Vault token, password, or `hvs.` value lives in a GitLab CI/CD
variable for this pipeline: GitLab's own signed job identity is the
credential, and it stops working the moment the job ends. Setting this up on
your own internal GitLab (issuer trust, the JWT auth method, and the
project-bound role) is out of scope for this doc — it is operator
infrastructure, not something `scripts/` in this repo configures.

Configure one GitLab pipeline schedule for the default branch with a weekly
interval to refresh the Ubuntu test pod and exercise both E2E jobs. The jobs are
also available as manual actions for targeted runs.

## Releases

Releases are deliberate and tag-driven; the version is never bumped by CI. The
full flow — `scripts/release prepare`, review, commit, tag, and the tag-gated
pipeline — is documented in [`VERSIONING.md`](VERSIONING.md). In short:

1. Normal pipelines only **validate** the `VERSION` format.
2. A maintainer prepares the version (`scripts/release prepare X.Y.Z`), commits,
   and pushes a tag `vX.Y.Z`.
3. The tag pipeline runs lint, secret scan, Ubuntu tests, macOS tests, and
   `version:verify`; only then does `release:artifacts` build the versioned
   tarball and `SHA256SUMS`. The release job re-checks that `CI_COMMIT_TAG`
   equals `v<VERSION>` exactly (for this project, **`v0.1.0`**).

Build the same checked artifact locally with `make package`.

## Secret scanning

The gating `secret-scan` job is **self-contained** (find + grep): it fails the
pipeline on any encrypted backup, live database, key material, rendered runtime
config, or high-signal secret content (age secret keys, PEM private keys, Vault
`hvs.` tokens). It needs no external image, so it always works internally.

An optional deeper scan, `secret-scan:gitleaks`, uses a **pinned** image
(`zricethezav/gitleaks:v8.18.4`). It is **off by default** so a green pipeline
never depends on pulling an external image; enable it by setting the CI/CD
variable `RUN_GITLEAKS=true`. Pin a newer version by editing the `image:` tag in
`.gitlab-ci.yml`.

## Notes on hardening the pipeline itself

- No job uses `privileged`, `services:`, or Docker-in-Docker.
- Container jobs run the distro's package install as the container's default
  user; nothing binds a network port or starts a daemon.
- `scripts/ci-local ubuntu` mounts the source **read-only** and runs with
  `--network none`.
