# github-actions


[![CI](https://github.com/trowaflo/github-actions/actions/workflows/ci.yml/badge.svg)](https://github.com/trowaflo/github-actions/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/trowaflo/github-actions)](https://github.com/trowaflo/github-actions/releases)
[![License](https://img.shields.io/github/license/trowaflo/github-actions)](LICENSE)

Reusable GitHub Actions workflows — source of truth for all `trowaflo/*` repositories.

All external `uses:` references are pinned to full commit SHAs. Renovate manages SHA updates automatically via `github>trowaflo/renovate-config`.

## Workflows

| Workflow | Defaults on | Documentation |
| --- | --- | --- |
| [`security.yml`](.github/workflows/security.yml) | gitleaks, kics | [docs/security.md](docs/security.md) |
| [`lint.yml`](.github/workflows/lint.yml) | actionlint | [docs/lint.md](docs/lint.md) |
| [`lint-renovate.yml`](.github/workflows/lint-renovate.yml) | — (all opt-in) | [docs/lint-renovate.md](docs/lint-renovate.md) |
| [`release.yml`](.github/workflows/release.yml) | — (all opt-in) | [docs/release.md](docs/release.md) |

What breaks a caller, and therefore cuts a major: [docs/contrat.md](docs/contrat.md).

## Quick start

Pin to a specific SHA (Renovate updates it automatically):

```yaml
# .github/workflows/ci.yml
name: CI
on: [pull_request]

permissions: {}

jobs:
  security:
    uses: trowaflo/github-actions/.github/workflows/security.yml@<sha> # vX.Y.Z
    permissions:
      contents: read
      pull-requests: write
      security-events: write

  lint:
    uses: trowaflo/github-actions/.github/workflows/lint.yml@<sha> # vX.Y.Z
    permissions:
      contents: read
      security-events: write
    with:
      enable_markdown_lint: true
      enable_yamllint: true
```

## Defaults philosophy

- **Security core** (`security.yml`): `enable_gitleaks`, `enable_kics` → `true` by default (opt-out); checkov, trivy, dependency-review → `false` (opt-in)
- **Lint core** (`lint.yml`): `enable_actionlint` → `true` by default (opt-out); all others → `false` (opt-in)
- **Triggers** — Security/lint workflows should use `on: [pull_request]` only, not `push` to `main`. Use `push` triggers for post-merge workflows: `release.yml`

## Security

- All `uses:` are SHA-pinned — never tags (`@v4`) or branches (`@main`)
- `ci.yml` enforces this with a `sha-check` job on every PR
- **KICS**, **Trivy**, **Checkov**, **actionlint**, **shellcheck** and **shfmt** upload results in SARIF format to **Security > Code scanning** on public repositories
- `enable_harden_runner` available on all workflows (default: `true`, egress `block`) — [StepSecurity harden-runner](https://github.com/step-security/harden-runner). Each job allows only the endpoints it downloads from; add yours with `harden_runner_allowed_endpoints`, or pass `audit` while you discover them
- KICS in `security.yml` via `enable_kics` (default: `true`) — runs the `checkmarx/kics` image pinned by digest, not `kics-github-action`, whose image is built from a mutable tag (⚠ TeamPCP supply chain attack, 2026-03-23)
- Checkov and the Renovate validator also run their image pinned by digest; ansible-lint installs from PyPI by hash
- Trivy IaC scanning in `security.yml` via `enable_trivy` (default: `false`)
- No job triggered by `pull_request` holds `contents: write`
