# CI/CD

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
