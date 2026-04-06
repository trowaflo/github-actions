# github-actions

[![CI](https://github.com/trowaflo/github-actions/actions/workflows/ci.yml/badge.svg)](https://github.com/trowaflo/github-actions/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/trowaflo/github-actions)](https://github.com/trowaflo/github-actions/releases)
[![License](https://img.shields.io/github/license/trowaflo/github-actions)](LICENSE)

Reusable GitHub Actions workflows — source of truth for all `trowaflo/*` repositories.

All external `uses:` references are pinned to full commit SHAs. Renovate manages SHA updates automatically via `github>trowaflo/renovate-config`.

## Workflows

| Workflow | Defaults on | Documentation |
| --- | --- | --- |
| [`quality.yml`](.github/workflows/quality.yml) | gitleaks, checkov, actionlint | [docs/quality.md](docs/quality.md) |
| [`ha.yml`](.github/workflows/ha.yml) | — (all opt-in) | [docs/ha.md](docs/ha.md) |
| [`python.yml`](.github/workflows/python.yml) | — (all opt-in) | [docs/python.md](docs/python.md) |
| [`helm.yml`](.github/workflows/helm.yml) | — (all opt-in) | [docs/helm.md](docs/helm.md) |
| [`docker.yml`](.github/workflows/docker.yml) | — (all opt-in) | [docs/docker.md](docs/docker.md) |
| [`release.yml`](.github/workflows/release.yml) | — (all opt-in) | [docs/release.md](docs/release.md) |
| [`claude-code.yml`](.github/workflows/claude-code.yml) | — (all opt-in) | [docs/claude-code.md](docs/claude-code.md) |
| [`validate-renovate.yml`](.github/workflows/validate-renovate.yml) | — (all opt-in) | [docs/validate-renovate.md](docs/validate-renovate.md) |

## Quick start

Pin to a specific SHA (Renovate updates it automatically):

```yaml
# .github/workflows/ci.yml
name: CI
on: [pull_request]

permissions: {}

jobs:
  quality:
    uses: trowaflo/github-actions/.github/workflows/quality.yml@<sha> # vX.Y.Z
    permissions:
      contents: read
      security-events: write
    with:
      harden_runner_allowed_endpoints: >
        github.com:443
        api.github.com:443
      enable_ansible_lint: true  # opt-in extras as needed
```

## Defaults philosophy

- **Security / universal quality** → `true` by default (opt-out): `enable_gitleaks`, `enable_checkov`, `enable_actionlint`
- **Domain-specific** → `false` by default (opt-in): everything else

## Security

- All `uses:` are SHA-pinned — never tags (`@v4`) or branches (`@main`)
- `ci.yml` enforces this with a `sha-check` job on every PR
- **Checkov**, **Trivy**, **KICS** and **actionlint** upload results in SARIF format to **Security > Code scanning** — inline annotations on PRs
- `enable_harden_runner` available on all workflows (default: `true`, egress `block`) — [StepSecurity harden-runner](https://github.com/step-security/harden-runner) blocks unauthorized network egress. Start with `harden_runner_egress_policy: audit` to discover endpoints, then switch to `block` with `harden_runner_allowed_endpoints`
- KICS available in `quality.yml` via `enable_kics` (⚠ TeamPCP supply chain attack, 2026-03-23 — prefer checkov)
- Trivy IaC scanning available in `quality.yml` via `enable_trivy`; container scanning in `docker.yml`
- Claude Code (`claude-code.yml`) — **requires access control on public repos**, restrict to `github.repository_owner` (see [docs](docs/claude-code.md))

## Deprecated

| Workflow | Replacement | Consumer |
| --- | --- | --- |
| `ha-integration.yml` | `ha.yml` + `python.yml` | frigate-event-manager |
| `lint-markdown.yml` | `quality.yml` with `enable_markdown_lint: true` | frigate-event-manager |
