# github-actions

Reusable GitHub Actions workflows — source of truth for all `trowaflo/*` repositories.

## Purpose

Centralise action pinning, versioning, and security policies across ~27 sibling repos. Every external `uses:` reference is pinned to a full commit SHA. Renovate manages SHA updates automatically.

## Workflows

| Workflow | Description | Defaults on |
| --- | --- | --- |
| [`quality.yml`](.github/workflows/quality.yml) | Secret scanning, IaC scan, workflow lint, dependency review, markdown/yaml/ansible/terraform lint | gitleaks, checkov, actionlint |
| [`ha.yml`](.github/workflows/ha.yml) | Home Assistant: pytest + ruff + codecov, HACS, hassfest, config check | — (all opt-in) |
| [`helm.yml`](.github/workflows/helm.yml) | Helm: release, lint, unittest, docs, bump, PR chart packages | — (all opt-in) |
| [`docker.yml`](.github/workflows/docker.yml) | Docker build/push + Trivy + grype container scanning | — (all opt-in) |
| [`release.yml`](.github/workflows/release.yml) | release-please + Claude Code + Claude Review | — (all opt-in) |

## Usage

Pin to a specific SHA (Renovate updates it automatically):

```yaml
# .github/workflows/ci.yml
name: CI
on: [pull_request, push]

jobs:
  quality:
    uses: trowaflo/github-actions/.github/workflows/quality.yml@<sha> # vX.Y.Z
    with:
      enable_gitleaks: true      # on by default
      enable_checkov: true       # on by default
      enable_actionlint: true    # on by default
      enable_ansible_lint: true  # opt-in

  release:
    uses: trowaflo/github-actions/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      enable_release_please: true
    secrets:
      release_token: ${{ secrets.RELEASE_TOKEN }}
```

## Defaults philosophy

- **Security / universal quality** (gitleaks, checkov, actionlint) → `true` by default (opt-out)
- **Domain-specific** (ansible, terraform, helm, HA, docker) → `false` by default (opt-in)

## Security

- All `uses:` are SHA-pinned — never tags (`@v4`) or branches (`@main`)
- `ci.yml` enforces this with a `sha-check` job on every PR
- KICS (`kics.yml`) is disabled — compromised by TeamPCP supply chain attack (2026-03-23)
- Checkov replaces KICS for IaC misconfiguration scanning
- Trivy and grype are available independently in `docker.yml` for container CVE scanning

## Deprecated workflows

These are kept for backward compatibility and will be removed after consumers migrate:

| Workflow | Replacement |
| --- | --- |
| `ha-integration.yml` | `ha.yml` with `enable_integration: true` |
| `lint-markdown.yml` | `quality.yml` with `enable_markdown_lint: true` |

## Self-CI

This repo validates itself via `ci.yml`:

- Calls `quality.yml` locally (gitleaks + checkov + actionlint + markdownlint)
- Runs `sha-check` — fails if any `uses:` is not pinned to a 40-char SHA
