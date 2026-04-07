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

Each workflow ships with a **built-in list of allowed endpoints** covering its own dependencies (pip, npm, Docker registries, etc.). Consumers can override with `harden_runner_allowed_endpoints` if needed — this **replaces** (does not merge with) the built-in defaults.

To observe endpoints before enforcing, start with `audit`:

```yaml
with:
  harden_runner_egress_policy: audit          # observe mode — no blocking
```

To override the built-in endpoint list (e.g. add private registry):

```yaml
with:
  harden_runner_egress_policy: block          # default
  harden_runner_allowed_endpoints: >
    github.com:443
    api.github.com:443
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

## quality.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_gitleaks` | `true` | Secret scanning |
| `enable_checkov` | `true` | IaC misconfig scan (replaces KICS) |
| `enable_actionlint` | `true` | Lint GitHub Actions workflow files |
| `enable_dependency_review` | `false` | CVE review on PR (requires pull_request event) |
| `enable_markdown_lint` | `false` | markdownlint-cli2 |
| `enable_yamllint` | `false` | yamllint |
| `enable_ansible_lint` | `false` | ansible-lint |
| `enable_terraform_validate` | `false` | terraform fmt + tflint |
| `enable_kics` | `true` | IaC scan via KICS (⚠ TeamPCP — SHA pinned pre-incident) |
| `enable_trivy` | `true` | IaC/filesystem scan via Trivy |
| `enable_json_lint` | `false` | JSON and JSON5 syntax validation |
| `checkov_framework` | `""` | terraform / kubernetes / helm / dockerfile / "" (all) |
| `trivy_severity` | `"UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"` | Trivy severity levels |

## ha.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_hacs` | `false` | HACS validation |
| `enable_hassfest` | `false` | hassfest validation |
| `enable_config_check` | `false` | HA config check |
| `ha_version` | `""` | HA version (required if enable_config_check, e.g. `2026.3.4`, `stable`) |
| `config_check_secrets` | `""` | Path to secrets file for config check (e.g. `secrets.fake.yaml`) |
| `config_check_setup` | `""` | Shell commands to run before config check (e.g. install custom components) |

## python.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
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
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_build` | `false` | Docker build & push via bake |
| `enable_trivy` | `false` | CVE scan via Trivy |
| `enable_grype` | `false` | CVE scan via grype |
| `registry` | `"ghcr.io"` | Target registry |
| `image_name` | `""` | Image name |
| `trivy_severity` | `""` | Trivy severity levels (empty = all) |

Secrets: `registry_username`, `registry_password` (both optional — defaults to GITHUB_TOKEN for ghcr.io)

## helm-ci.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_lint` | `false` | Lint charts with chart-testing (ct lint) |
| `enable_unittest` | `false` | Helm unit tests with helm-unittest (matrix per chart) |
| `enable_bump` | `false` | Auto-bump chart versions on PR using conventional commits |
| `enable_docs` | `false` | Generate and commit helm-docs (runs after bump) |
| `enable_docs_check` | `false` | Validate documentation is up-to-date (fails if outdated) |
| `enable_pr_charts` | `false` | Package modified charts on PR and publish to pr-charts branch |
| `charts_dir` | `"charts"` | Root directory for Helm charts |
| `bump_skip_actors` | `"renovate[bot]"` | Comma-separated actors to skip for version bumping |

## helm-release.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_release` | `false` | Release charts via chart-releaser (multi-dir support via release_charts_dirs) |
| `charts_dir` | `"charts"` | Root directory for Helm charts |
| `release_charts_dirs` | `""` | Space-separated ordered chart directories to release (max 2) |

## helm-pr-cleanup.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |

## release.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_release_please` | `false` | Automated releases via release-please |
| `release_config_file` | `""` | Path to release-please-config.json |
| `release_manifest_file` | `""` | Path to .release-please-manifest.json |

Secret: `release_token` (optional — uses GITHUB_TOKEN if absent)

## claude-code.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |

Secret: `claude_code_oauth_token` (required)

## validate-renovate.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `node_version` | `"22"` | Node.js version for renovate-config-validator |
| `config_files` | `""` | Glob pattern of files to validate (default: `*.json` `*.json5` at root) |

