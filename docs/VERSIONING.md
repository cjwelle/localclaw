# Versioning

This project uses [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).
The file [`../VERSION`](../VERSION) is the **single source of truth** for the
current version; everything else (the CHANGELOG heading, the git tag, release
artifact names) is derived from or checked against it.

## The rules in one screen

- **`VERSION` is canonical.** It always holds a bare `MAJOR.MINOR.PATCH` string
  (e.g. `0.1.0`) with no `v` prefix and no pre-release suffix.
- **Tags are `v` + VERSION.** A release tag is `vMAJOR.MINOR.PATCH` (e.g.
  `v0.1.0`). The tag pipeline refuses to publish unless `CI_COMMIT_TAG` equals
  `v$(cat VERSION)` **exactly**. For the current project that means the release
  tag must be **`v0.1.0`**.
- **Canonical tags always use full SemVer.** A feature release is tagged like
  `v1.0.0` or `v2.5.0`; a patch release is tagged like `v1.0.1` or `v2.5.1`.
  Human-facing notes may describe `v1.0.1` as “1.0 patch 1,” but shorthand such
  as `1.0-1` is never used as the git tag, `VERSION`, artifact version, or
  release identifier.
- **Normal pipelines only validate the format.** A push or merge-request
  pipeline checks that `VERSION` is a well-formed SemVer. It does **not** bump,
  tag, or publish anything.
- **Releases are deliberate.** A release happens only when a maintainer creates
  the matching tag, and only after lint, the secret scan, the Ubuntu tests, and
  the native macOS tests have passed. CI never auto-increments the version just
  because it ran.
- **No tooling commits, tags, or pushes.** [`scripts/release`](../scripts/release)
  edits files only; the maintainer performs the git actions.

## What increments when

Because this is a security baseline made of shell scripts, config templates, and
Vault policies, we map SemVer to observable behavior:

| Change | Bump |
| --- | --- |
| A security invariant is removed or weakened; a script's flags/behavior change incompatibly; config/template keys are renamed or removed; a policy grants materially more. | **MAJOR** |
| New script, new subcommand/flag, new config key, or a new opt-in capability that keeps existing behavior working. | **MINOR** |
| Bug fix, doc fix, hardening that does not change the interface, or an internal refactor. | **PATCH** |

Pre-`1.0.0` (where we are now), the public surface is still settling: a MINOR
bump may include small, clearly-documented breaking changes. We call those out
explicitly in the CHANGELOG.

## The release flow

1. **Land the work.** Merge the changes; keep the CHANGELOG's `## [Unreleased]`
   section current (this is a contributor requirement — see
   [`CONTRIBUTING.md`](CONTRIBUTING.md)).
2. **Prepare the version.** Run the helper — it edits `VERSION` and the CHANGELOG
   only and makes **no** git changes:

   ```sh
   scripts/release prepare 0.2.0            # dated today
   scripts/release prepare 0.2.0 --date 2026-09-01
   ```

   This sets `VERSION=0.2.0` and converts `## [Unreleased]` into
   `## [0.2.0] - <date>` with a fresh empty `## [Unreleased]` above it.
3. **Review, then commit and tag yourself.** The helper prints the exact
   commands; nothing is committed for you:

   ```sh
   git add VERSION CHANGELOG.md
   git commit -m "release: v0.2.0"
   git tag -a v0.2.0 -m "v0.2.0"
   git push origin main --follow-tags
   ```
4. **The tag pipeline gates the release.** It re-runs lint, the secret scan, the
   Ubuntu tests, and the macOS tests, then verifies `CI_COMMIT_TAG == v0.2.0`
   before building the release artifact and its checksums.

## Updating an installed checkout

Published canonical tags are the normal update inputs for existing machines.
Run `scripts/update --check`, review the changelog, then apply an approved tag
with `scripts/update --to vX.Y.Z`. The updater fast-forwards the wrapper
checkout, preserves XDG config/state and the separately installed OpenClaw
package, and runs the release/version and doctor checks afterward. It refuses
dirty trees, active sessions, non-fast-forward history, and missing encrypted
backup evidence unless the operator explicitly supplies `--allow-no-backup`.

## `scripts/release` reference

```text
scripts/release current            # print the canonical VERSION
scripts/release verify             # validate VERSION format (normal pipeline)
scripts/release verify --tag v0.1.0# also require the tag to equal v<VERSION>
scripts/release prepare <version>  # edit VERSION + CHANGELOG (never git)
scripts/release prepare <version> --date YYYY-MM-DD
```

- `verify` reads `CI_COMMIT_TAG` from the environment (GitLab sets it on tag
  pipelines) or from `--tag`. With a tag present it fails unless the tag is
  exactly `v<VERSION>`; with no tag it only checks the format.
- `prepare` refuses a non-SemVer version and refuses any version that is not
  **strictly greater** than the current one — it never downgrades and never
  auto-increments.
- `OSLS_RELEASE_ROOT` overrides the repository root the tool operates on. The
  test-suite uses it to run `prepare` against a throwaway copy so the real
  `VERSION`/`CHANGELOG` are never touched by tests.

## Supported versions

The security-support policy tracks **published release lines** only. See
[`SECURITY.md`](SECURITY.md) (and the top-level
[`../SECURITY.md`](../SECURITY.md)) for the current support table. A version line
appears there as "supported" only once it has actually been released — we do not
advertise support for versions that do not exist yet.
