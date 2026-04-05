# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository is the **source of truth** for all GitHub Actions workflows across ~27 sibling repos. It provides reusable workflows (`workflow_call`) that centralise action pinning, versioning, and security policies. All validation happens in CI via GitHub Actions — there is no local build system.

## Repository structure

```
.github/workflows/
  # ─── Reusable workflows (call from other repos) ──────────────
  quality.yml          # Security + Linting: gitleaks, checkov, actionlint, dependency-review,
                       #   markdownlint, yamllint, ansible-lint, terraform-validate
  ha.yml               # Home Assistant: hacs, hassfest, config-check
  python.yml           # Python CI: pytest+ruff+codecov (generic — HA uses extra_packages)
  helm.yml             # Helm: release, lint, unittest, docs, bump, PR charts, PR cleanup
  docker.yml           # Docker: build/push, trivy scan, grype scan
  release.yml          # Release: release-please
  claude-code.yml      # Claude Code: @claude mentions + /review command

  # ─── Self-CI (this repo only) ────────────────────────────────
  ci.yml               # Calls quality.yml locally + sha-check (enforces SHA pinning)
  claude.yml           # Claude Code — restricted to repository_owner only
  release-please.yml   # Creates tags and CHANGELOG on main push

  # ─── Deprecated (kept for backward compat) ───────────────────
  ha-integration.yml   # DEPRECATED → migrate to ha.yml + python.yml — consumer: frigate-event-manager
  lint-markdown.yml    # DEPRECATED → migrate to quality.yml — consumer: frigate-event-manager

  # ─── Archived ────────────────────────────────────────────────
  kics.yml             # DISABLED — supply chain attack on checkmarx/kics-github-action (2026-03-23)
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

- **Security / quality universelle** (gitleaks, checkov, actionlint) → `true` by default (opt-out)
- **Domain-specific** (ansible, terraform, helm, HA, docker) → `false` by default (opt-in)

### KICS workflow

The KICS workflow (`kics.yml`) is intentionally disabled due to a supply chain attack on `checkmarx/kics-github-action` detected on 2026-03-23 (TeamPCP campaign). It is **not** re-enabled — `checkov` (Bridgecrew/Prisma Cloud) replaces it in `quality.yml` and was not impacted by TeamPCP.

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
jobs:
  quality:
    uses: trowaflo/github-actions/.github/workflows/quality.yml@<sha> # vX.Y.Z
    with:
      enable_gitleaks: true      # default
      enable_checkov: true       # default
      enable_actionlint: true    # default
      enable_ansible_lint: true  # opt-in for ansible repos
```

## quality.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_gitleaks` | `true` | Secret scanning |
| `enable_checkov` | `true` | IaC misconfig scan (replaces KICS) |
| `enable_actionlint` | `true` | Lint GitHub Actions workflow files |
| `enable_dependency_review` | `false` | CVE review on PR (requires pull_request event) |
| `enable_markdown_lint` | `false` | markdownlint-cli2 |
| `enable_yamllint` | `false` | yamllint |
| `enable_ansible_lint` | `false` | ansible-lint |
| `enable_terraform_validate` | `false` | terraform fmt + tflint |
| `checkov_framework` | `""` | terraform / kubernetes / helm / dockerfile / "" (all) |

## ha.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_hacs` | `false` | HACS validation |
| `enable_hassfest` | `false` | hassfest validation |
| `enable_config_check` | `false` | HA config check |
| `ha_version` | `""` | HA version (required if enable_config_check) |

## python.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_test` | `false` | pytest + codecov |
| `enable_lint` | `false` | ruff lint |
| `python_version` | `"3.13"` | Python version |
| `coverage_threshold` | `"80"` | Minimum coverage % |
| `test_path` | `"tests/"` | Test directory |
| `coverage_path` | `"."` | Coverage source path (e.g. `custom_components/my_component`) |
| `extra_packages` | `""` | Additional pip packages (e.g. `pytest-homeassistant-custom-component==0.13.316`) |

Secret: `codecov_token` (optional)

## docker.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_build` | `false` | Docker build & push via bake |
| `enable_trivy` | `false` | CVE scan via Trivy |
| `enable_grype` | `false` | CVE scan via grype |
| `registry` | `"ghcr.io"` | Target registry |
| `image_name` | `""` | Image name |
| `trivy_severity` | `""` | Trivy severity levels (empty = all) |

Secrets: `registry_username`, `registry_password` (both optional — defaults to GITHUB_TOKEN for ghcr.io)
