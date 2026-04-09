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
| [`ci-ha.yml`](.github/workflows/ci-ha.yml) | — (all opt-in) | [docs/ci-ha.md](docs/ci-ha.md) |
| [`ci-python.yml`](.github/workflows/ci-python.yml) | — (all opt-in) | [docs/ci-python.md](docs/ci-python.md) |
| [`ci-helm.yml`](.github/workflows/ci-helm.yml) | — (all opt-in) | [docs/helm.md](docs/helm.md) |
| [`release-helm.yml`](.github/workflows/release-helm.yml) | — (all opt-in) | [docs/helm.md](docs/helm.md) |
| [`ci-helm-cleanup.yml`](.github/workflows/ci-helm-cleanup.yml) | — (all opt-in) | [docs/helm.md](docs/helm.md) |
| [`ci-docker.yml`](.github/workflows/ci-docker.yml) | — (all opt-in) | [docs/ci-docker.md](docs/ci-docker.md) |
| [`release.yml`](.github/workflows/release.yml) | — (all opt-in) | [docs/release.md](docs/release.md) |
| [`claude-code.yml`](.github/workflows/claude-code.yml) | — (all opt-in) | [docs/claude-code.md](docs/claude-code.md) |

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
- **Domain-specific** (helm, HA, docker, python) → `false` by default (opt-in)
- **Triggers** — Security/lint workflows should use `on: [pull_request]` only, not `push` to `main`. Use `push` triggers for post-merge workflows: `release.yml`, `ci-docker.yml` (publish), `release-helm.yml` (chart release)

## Security

- All `uses:` are SHA-pinned — never tags (`@v4`) or branches (`@main`)
- `ci.yml` enforces this with a `sha-check` job on every PR
- **KICS**, **Trivy**, **Checkov**, and **actionlint** upload results in SARIF format to **Security > Code scanning** — inline annotations on PRs
- `enable_harden_runner` available on all workflows (default: `true`, egress `audit`) — [StepSecurity harden-runner](https://github.com/step-security/harden-runner). Switch to `block` once endpoints are known
- KICS in `security.yml` via `enable_kics` (default: `true`) — ⚠ TeamPCP supply chain attack (2026-03-23), SHA pinned to pre-incident commit
- Trivy IaC scanning in `security.yml` via `enable_trivy` (default: `false`); container scanning in `ci-docker.yml`
- Claude Code (`claude-code.yml`) — **requires access control on public repos**, restrict to `github.repository_owner` (see [docs](docs/claude-code.md))
