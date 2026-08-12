# Security Policy

This file is the vulnerability-reporting policy for the
**localclaw** repository. For the stack's *security model*
(how the running system protects secrets), see
[`docs/SECURITY.md`](docs/SECURITY.md).

## Supported versions

Security support tracks **published release lines** only. A line is listed here
as supported **once it has actually been released** — we do not claim support
for versions that do not exist yet. Support means the latest patch release on
that line receives security fixes; older patch releases on the line are expected
to upgrade to it.

The canonical current version is in [`VERSION`](VERSION) (see
[`docs/VERSIONING.md`](docs/VERSIONING.md)). This project is at **0.1.0**, so the
`0.1.x` line is the one under support.

| Version line | Supported | Notes |
| ------------ | --------- | ----- |
| `0.1.x`      | ✅ Yes     | Current release line. |
| `< 0.1.0`    | ❌ No      | Pre-release / never published. |

Future lines are added here **only when released** — e.g. entries such as
`1.5.x`, `2.0.x`, or `2.5.x` are illustrations of how this table will grow and
are **not** supported today because they do not exist yet. When a new line ships,
the previous line's support window is stated in the release notes at that time.

## Reporting a vulnerability

Please report suspected vulnerabilities **privately** — do not open a public
issue for anything exploitable. Use either of the following:

- The repository host's private advisory workflow
  (e.g. GitLab confidential issue / GitHub private security advisory).
- The project maintainer and security contact:
  **Christopher Welle** &lt;cjwelle@gmail.com&gt;.

When reporting, please include:

- affected version (`VERSION`) and platform (macOS / Ubuntu / Debian),
- a description of the issue and its impact,
- reproduction steps or a proof of concept, and
- any suggested remediation.

**Never include real secrets** in a report — no Vault tokens, unseal shares,
recovery keys, API keys, or private `age` identities. Redact them.

## Response expectations

This is a single-maintainer, best-effort project. Expect an **initial
acknowledgement within 1–2 weeks** of a report. After triage we will agree on a
remediation timeline based on severity; fixes ship on the current supported
release line (see above). If you do not hear back within two weeks, please send a
polite follow-up in case the original report was missed.

## Scope

In scope: the scripts, templates, policies, and documentation in this
repository. Out of scope: upstream HashiCorp Vault, OpenClaw, `age`, SQLite, or
your operating system — report those to their respective projects.
