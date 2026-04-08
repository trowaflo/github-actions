# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository is the **source of truth** for all GitHub Actions workflows across ~27 sibling repos. It provides reusable workflows (`workflow_call`) that centralise action pinning, versioning, and security policies. All validation happens in CI via GitHub Actions — there is no local build system.

## Repository structure

```
.github/workflows/
  # ─── Reusable workflows (call from other repos) ──────────────
  quality.yml          # Security + Linting: gitleaks, checkov, actionlint, dependency-review,
                       #   markdownlint, yamllint, ansible-lint, terraform-validate, kics, trivy, json-lint
  ha.yml               # Home Assistant: hacs, hassfest, config-check
  python.yml           # Python CI: pytest+ruff+codecov (generic — HA uses extra_packages)
  helm-ci.yml          # Helm CI: lint, unittest, bump, docs, docs-check, pr-charts (pull_request)
  helm-release.yml     # Helm Release: chart-releaser (push to main)
  helm-pr-cleanup.yml  # Helm Cleanup: remove pr-charts on PR close
  docker.yml           # Docker: build/push, trivy scan, grype scan
  release.yml          # Release: release-please
  claude-code.yml      # Claude Code: @claude mentions + /review command
  validate-renovate.yml # Renovate: config file validation

  # ─── Self-CI (this repo only) ────────────────────────────────
  ci.yml               # Calls quality.yml locally + sha-check (enforces SHA pinning)
  claude.yml           # Claude Code — restricted to repository_owner only
  release-please.yml   # Creates tags and CHANGELOG on main push

  # ─── Deprecated (kept for backward compat) ───────────────────
  ha-integration.yml   # DEPRECATED → migrate to ha.yml + python.yml — consumer: frigate-event-manager
  lint-markdown.yml    # DEPRECATED → migrate to quality.yml — consumer: frigate-event-manager

```

## Key conventions

### Action pinning

All `uses:` references **must** be pinned to a full commit SHA (40 hex chars), with a version comment:

```yaml
uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
```

Never use tags (`@v4`) or branch names (`@main`). Renovate handles SHA updates automatically.
The `ci.yml` sha-check job enforces this on every PR — it will fail if any unpinned `uses:` is found.

### Renovate

Dependency updates are managed by Renovate using the shared config at `github>trowaflo/renovate-config`. Do not add local `packageRules` unless overriding that shared config.

### Defaults philosophy

- **Security / quality universelle** (gitleaks, checkov, actionlint, kics, trivy) → `true` by default (opt-out)
- **Domain-specific** (ansible, terraform, helm, HA, docker) → `false` by default (opt-in)

### Harden Runner

All reusable workflows enable [StepSecurity harden-runner](https://github.com/step-security/harden-runner) by default (`enable_harden_runner: true`). The default egress policy is `block` — all outbound network traffic is denied unless explicitly allowed.

Each workflow ships with a **built-in list of allowed endpoints** covering its own dependencies (pip, npm, Docker registries, etc.). These built-in defaults are **always applied**. Consumers can pass extra endpoints via `harden_runner_allowed_endpoints` — they are **merged** (union) with the built-in defaults, not replaced.

To observe endpoints before enforcing, start with `audit`:

```yaml
with:
  harden_runner_egress_policy: audit          # observe mode — no blocking
```

To add extra endpoints (e.g. private registry) — built-in defaults remain active:

```yaml
with:
  harden_runner_allowed_endpoints: >
    my-private-registry.example.com:443
```

### KICS

KICS is available in `quality.yml` via `enable_kics` (default: `true`). Note: `checkmarx/kics-github-action` was impacted by the TeamPCP supply chain attack (2026-03-23) — the current SHA is pinned to a pre-incident commit (`v2.1.20`, 2026-03-04).

### IaC scanning (Trivy)

`quality.yml` provides `enable_trivy` for IaC/filesystem scanning via `aquasecurity/trivy-action`. Severity is configurable via `trivy_severity` (default: all levels). This is independent from the container Trivy scan in `docker.yml`.

### Container scanning (Trivy vs grype)

`docker.yml` provides two independent container scanning jobs:

- `enable_trivy` — aquasecurity/trivy-action, SHA-pinned post-incident
- `enable_grype` — anchore/scan-action, never impacted by TeamPCP

Both are `false` by default. Enable one, both, or neither depending on the repo.

## Consumer usage example

```yaml
# .github/workflows/ci.yml (in a consumer repo)
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
      enable_gitleaks: true      # default
      enable_checkov: true       # default
      enable_actionlint: true    # default
      enable_ansible_lint: true  # opt-in for ansible repos
```

### Triggers — `pull_request` only

Quality/lint workflows should trigger on `pull_request` only — **not** on `push` to `main`. A push to `main` happens after a PR merge, so the same checks would run twice (once on the PR, once on the push). Use `push` triggers only for workflows that must run post-merge: `release.yml` (release-please), `docker.yml` (build & publish), `helm.yml` (chart release).

## Inputs reference

All inputs (including secrets) are documented inline in each workflow file — read the file directly for the full list. Shared across all workflows: `enable_harden_runner` (default: `true`), `harden_runner_egress_policy` (default: `"block"`), `harden_runner_allowed_endpoints` (extra endpoints merged with built-in defaults).

Key files: `quality.yml`, `ha.yml`, `python.yml`, `helm-ci.yml`, `helm-release.yml`, `helm-pr-cleanup.yml`, `docker.yml`, `release.yml`, `claude-code.yml`, `validate-renovate.yml`

