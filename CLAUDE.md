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
  helm.yml             # Helm: release, lint, unittest, docs, docs-check, bump, PR charts, PR cleanup
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

## helm.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_release` | `false` | Release charts via chart-releaser (multi-dir support via release_charts_dirs) |
| `enable_lint` | `false` | Lint charts with chart-testing (ct lint) |
| `enable_unittest` | `false` | Helm unit tests with helm-unittest (matrix per chart) |
| `enable_docs` | `false` | Generate and commit documentation with helm-docs |
| `enable_docs_check` | `false` | Validate documentation is up-to-date (dry-run, fails if outdated) |
| `enable_bump` | `false` | Auto-bump chart versions on PR using conventional commits (major/minor/patch) |
| `enable_pr_charts` | `false` | Package modified charts on PR and publish to pr-charts branch |
| `enable_pr_cleanup` | `false` | Cleanup PR charts from pr-charts branch after merge/close |
| `charts_dir` | `"charts"` | Root directory for Helm charts |
| `release_charts_dirs` | `""` | Space-separated ordered chart directories to release (max 2) |
| `bump_skip_actors` | `"renovate[bot]"` | Comma-separated actors to skip for version bumping |

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

<!-- rtk-instructions v2 -->
# RTK (Rust Token Killer) - Token-Optimized Commands

## Golden Rule

**Always prefix commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

## RTK Commands by Workflow

### Build & Compile (80-90% savings)
```bash
rtk cargo build         # Cargo build output
rtk cargo check         # Cargo check output
rtk cargo clippy        # Clippy warnings grouped by file (80%)
rtk tsc                 # TypeScript errors grouped by file/code (83%)
rtk lint                # ESLint/Biome violations grouped (84%)
rtk prettier --check    # Files needing format only (70%)
rtk next build          # Next.js build with route metrics (87%)
```

### Test (90-99% savings)
```bash
rtk cargo test          # Cargo test failures only (90%)
rtk vitest run          # Vitest failures only (99.5%)
rtk playwright test     # Playwright failures only (94%)
rtk test <cmd>          # Generic test wrapper - failures only
```

### Git (59-80% savings)
```bash
rtk git status          # Compact status
rtk git log             # Compact log (works with all git flags)
rtk git diff            # Compact diff (80%)
rtk git show            # Compact show (80%)
rtk git add             # Ultra-compact confirmations (59%)
rtk git commit          # Ultra-compact confirmations (59%)
rtk git push            # Ultra-compact confirmations
rtk git pull            # Ultra-compact confirmations
rtk git branch          # Compact branch list
rtk git fetch           # Compact fetch
rtk git stash           # Compact stash
rtk git worktree        # Compact worktree
```

Note: Git passthrough works for ALL subcommands, even those not explicitly listed.

### GitHub (26-87% savings)
```bash
rtk gh pr view <num>    # Compact PR view (87%)
rtk gh pr checks        # Compact PR checks (79%)
rtk gh run list         # Compact workflow runs (82%)
rtk gh issue list       # Compact issue list (80%)
rtk gh api              # Compact API responses (26%)
```

### JavaScript/TypeScript Tooling (70-90% savings)
```bash
rtk pnpm list           # Compact dependency tree (70%)
rtk pnpm outdated       # Compact outdated packages (80%)
rtk pnpm install        # Compact install output (90%)
rtk npm run <script>    # Compact npm script output
rtk npx <cmd>           # Compact npx command output
rtk prisma              # Prisma without ASCII art (88%)
```

### Files & Search (60-75% savings)
```bash
rtk ls <path>           # Tree format, compact (65%)
rtk read <file>         # Code reading with filtering (60%)
rtk grep <pattern>      # Search grouped by file (75%)
rtk find <pattern>      # Find grouped by directory (70%)
```

### Analysis & Debug (70-90% savings)
```bash
rtk err <cmd>           # Filter errors only from any command
rtk log <file>          # Deduplicated logs with counts
rtk json <file>         # JSON structure without values
rtk deps                # Dependency overview
rtk env                 # Environment variables compact
rtk summary <cmd>       # Smart summary of command output
rtk diff                # Ultra-compact diffs
```

### Infrastructure (85% savings)
```bash
rtk docker ps           # Compact container list
rtk docker images       # Compact image list
rtk docker logs <c>     # Deduplicated logs
rtk kubectl get         # Compact resource list
rtk kubectl logs        # Deduplicated pod logs
```

### Network (65-70% savings)
```bash
rtk curl <url>          # Compact HTTP responses (70%)
rtk wget <url>          # Compact download output (65%)
```

### Meta Commands
```bash
rtk gain                # View token savings statistics
rtk gain --history      # View command history with savings
rtk discover            # Analyze Claude Code sessions for missed RTK usage
rtk proxy <cmd>         # Run command without filtering (for debugging)
rtk init                # Add RTK instructions to CLAUDE.md
rtk init --global       # Add RTK to ~/.claude/CLAUDE.md
```

## Token Savings Overview

| Category | Commands | Typical Savings |
|----------|----------|-----------------|
| Tests | vitest, playwright, cargo test | 90-99% |
| Build | next, tsc, lint, prettier | 70-87% |
| Git | status, log, diff, add, commit | 59-80% |
| GitHub | gh pr, gh run, gh issue | 26-87% |
| Package Managers | pnpm, npm, npx | 70-90% |
| Files | ls, read, grep, find | 60-75% |
| Infrastructure | docker, kubectl | 85% |
| Network | curl, wget | 65-70% |

Overall average: **60-90% token reduction** on common development operations.
<!-- /rtk-instructions -->