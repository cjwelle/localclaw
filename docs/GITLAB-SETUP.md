# GitLab project and runners

> For the end-to-end self-hosting sequence, read [`SELF-HOSTING.md`](SELF-HOSTING.md).
> This file focuses on GitLab project creation, runners, and maintainer-only CI
> configuration.

This runbook prepares a new internal GitLab project and the two runners required
by [`.gitlab-ci.yml`](../.gitlab-ci.yml): an untagged Docker executor for Ubuntu
jobs and a native macOS shell executor tagged `macos`.

No credentials, tokens, or runner configuration belong in this repository.
Obtain short-lived project access and runner authentication tokens from your
GitLab administrator and enter them only at the command prompt.

## 1. Create the GitLab project

Create a blank private project in the GitLab UI with no generated README,
license, or `.gitignore`. Record its SSH URL, then run from the repository root:

```sh
export GITLAB_SSH_URL='git@gitlab.example.com:group/openclaw-secure-local-stack.git'
git remote add origin "$GITLAB_SSH_URL"
git remote -v
```

If the GitLab CLI is installed and authenticated, the equivalent project
creation command is:

```sh
export GITLAB_HOST='gitlab.example.com'
export GITLAB_NAMESPACE='group'
glab repo create "$GITLAB_NAMESPACE/openclaw-secure-local-stack" \
  --private --default-branch main --source . --remoteName origin
```

Review the initial change set before creating the first commit:

```sh
make check
make test
git status --short
git add .
git diff --cached --check
git diff --cached --stat
git commit -m 'Initial release of secure local OpenClaw stack'
git push --set-upstream origin main
```

The commands above are intentionally manual. Do not paste them into unattended
automation because project creation and pushing change external state.

## 2. Create runner authentication tokens

In GitLab, open **Project > Settings > CI/CD > Runners** and create two project
runners:

1. `openclaw-ubuntu-docker`: no tags; enable **Run untagged jobs**.
2. `openclaw-macos-shell`: tag `macos`; disable **Run untagged jobs**.

GitLab displays a `glrt-...` runner authentication token once for each runner.
Keep each token out of shell history. The examples below read tokens silently.

## 3. Register the Docker runner

The following uses the official GitLab Runner container and the local Docker
daemon. Set `GITLAB_URL` to the internal GitLab base URL, including `https://`.

```sh
export GITLAB_URL='https://gitlab.example.com'
read -r -s -p 'Ubuntu runner token: ' UBUNTU_RUNNER_TOKEN; echo

docker volume create gitlab-runner-config
docker run -d --name gitlab-runner --restart always \
  -v gitlab-runner-config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest

docker run --rm -i \
  -v gitlab-runner-config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest register --non-interactive \
  --url "$GITLAB_URL" \
  --token "$UBUNTU_RUNNER_TOKEN" \
  --executor docker \
  --docker-image ubuntu:latest \
  --description openclaw-ubuntu-docker \
  --run-untagged=true \
  --locked=true

unset UBUNTU_RUNNER_TOKEN
docker logs --tail 50 gitlab-runner
```

This runner is not privileged. The pipeline does not use Docker-in-Docker or
service containers. Pin the `gitlab/gitlab-runner` image to an approved version
in regulated environments rather than using `latest`.

## 4. Register the native macOS runner

Run these commands on the Mac that will execute CI. This host must remain
available whenever main-branch, merge-request, or release-tag pipelines run.

```sh
brew install gitlab-runner
export GITLAB_URL='https://gitlab.example.com'
read -r -s -p 'macOS runner token: ' MACOS_RUNNER_TOKEN; echo

gitlab-runner register --non-interactive \
  --url "$GITLAB_URL" \
  --token "$MACOS_RUNNER_TOKEN" \
  --executor shell \
  --description openclaw-macos-shell \
  --tag-list macos \
  --run-untagged=false \
  --locked=true

unset MACOS_RUNNER_TOKEN
brew services start gitlab-runner
gitlab-runner verify
```

The macOS runner executes repository code as its service account. Use a
dedicated, non-administrator account with no production credentials, Vault
tokens, cloud profiles, or personal data. Do not use the daily workstation
account for shared or untrusted merge requests.

## 5. Validate the pipeline

Before pushing, mirror the CI checks locally:

```sh
scripts/ci-local native
scripts/ci-local all
```

After the first push, confirm both runners are online in GitLab and verify that:

- Ubuntu jobs run on `openclaw-ubuntu-docker`.
- `test:macos` runs on `openclaw-macos-shell`.
- `secret-scan`, `version:verify`, and `package` pass.
- No project variable contains a Vault token, age identity, API key, or provider
  credential.

The optional pinned gitleaks job can be enabled with the project CI/CD variable
`RUN_GITLEAKS=true`. It is not required for the default pipeline.

### Validate the E2E jobs specifically

After the normal checks pass, play `e2e:macos` and `e2e:ubuntu` manually from
the pipeline UI. Confirm both jobs show the Vault login step and finish with
the lifecycle pass message. If Ubuntu reports that Vault did not start, first
check that the checkout includes the runtime port allocator and Python listener
probe in `tests/e2e/run.sh` and `scripts/lib/common.sh`; do not add a long-lived
Vault token as a workaround.

## 6. Release

Follow [`VERSIONING.md`](VERSIONING.md). A release requires an intentionally
prepared version commit and matching tag:

```sh
scripts/release prepare 0.2.0
make check
make test
git add VERSION CHANGELOG.md
git commit -m 'Release 0.2.0'
git tag -s v0.2.0 -m 'openclaw-secure-local-stack 0.2.0'
git push origin main v0.2.0
```

Use an unsigned annotated tag (`git tag -a`) only when the internal GitLab does
not support the maintainer's signing workflow. The tag pipeline packages the
release only after all required jobs pass.
