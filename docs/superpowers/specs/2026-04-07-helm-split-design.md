# Helm Workflows Split — Design Spec

**Date:** 2026-04-07
**Branch:** refactor/helm-workflow
**Status:** Approved

## Context

`helm.yml` is a monolithic reusable workflow with 8 jobs controlled by `enable_*` flags. It is called up to 3 times with different flag sets:

- On `pull_request`: lint, unittest, bump, docs-check, pr-charts
- On `push` to main: release, docs
- On PR `closed`: pr-cleanup

Problems:
- Cascading `if:` conditions make the file hard to read
- `bump` and `docs-check` run in parallel → docs become stale after bump commits a new version
- No way to enforce `bump → docs → docs-check` ordering without ugly composite conditions

## Decision

Split into 3 dedicated reusable workflow files. Delete `helm.yml`.

## Files

### `helm-ci.yml` — Pull Request CI

**Trigger context:** `pull_request`

**Job sequence:**

```
helm-lint ──┐
            ├──→ helm-bump ──→ helm-docs ──→ helm-docs-check
helm-unittest      │
(matrix)           └──────────────────────→ helm-pr-charts
```

- `helm-lint` and `helm-unittest` run in parallel
- `helm-bump` needs both to pass (no version bump on broken charts)
- `helm-docs` needs `helm-bump` (regenerates README after version change)
- `helm-docs-check` needs `helm-docs` (validates after regeneration)
- `helm-pr-charts` needs `helm-bump` (packages the bumped version)

**Inputs:**

| Input | Default | Description |
|---|---|---|
| `enable_harden_runner` | `true` | StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | `audit` or `block` |
| `harden_runner_allowed_endpoints` | (built-in) | Override replaces defaults |
| `enable_lint` | `false` | `ct lint` |
| `enable_unittest` | `false` | helm-unittest (matrix per chart) |
| `enable_bump` | `false` | Auto-bump versions from conventional commits |
| `enable_docs` | `false` | Generate + commit helm-docs after bump |
| `enable_docs_check` | `false` | Validate docs are up-to-date |
| `enable_pr_charts` | `false` | Package charts and publish to pr-charts branch |
| `charts_dir` | `"charts"` | Root directory for Helm charts |
| `bump_skip_actors` | `"renovate[bot]"` | Actors to skip for version bumping |

---

### `helm-release.yml` — Release on main

**Trigger context:** `push` to main

**Job sequence:**

```
helm-release ──→ helm-docs
```

- `helm-docs` needs `helm-release` (commits docs after charts are released)

**Inputs:**

| Input | Default | Description |
|---|---|---|
| `enable_harden_runner` | `true` | StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | `audit` or `block` |
| `harden_runner_allowed_endpoints` | (built-in) | Override replaces defaults |
| `enable_release` | `false` | chart-releaser (multi-dir via `release_charts_dirs`) |
| `enable_docs` | `false` | Generate + commit helm-docs |
| `charts_dir` | `"charts"` | Root directory for Helm charts |
| `release_charts_dirs` | `""` | Space-separated chart dirs to release (max 2) |

---

### `helm-pr-cleanup.yml` — PR Cleanup

**Trigger context:** PR `closed` (merged or abandoned)

**Jobs:** single `helm-pr-cleanup` job — no enable flag (calling this workflow implies cleanup intent)

**Inputs:**

| Input | Default | Description |
|---|---|---|
| `enable_harden_runner` | `true` | StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | `audit` or `block` |
| `harden_runner_allowed_endpoints` | (built-in) | Override replaces defaults |

---

## Documentation updates

| File | Action |
|---|---|
| `docs/helm.md` | Replace with 3 sections — one per workflow — with inputs tables and usage examples |
| `CLAUDE.md` | Replace `helm.yml inputs` section with 3 separate tables |

## Migration

`helm.yml` is deleted. Consumer repo (`../helm-charts`) is updated by the user to call the 3 new workflows.

## What is NOT changed

- All job implementations (shell scripts, action SHAs, caching) are copied as-is
- Harden-runner pattern unchanged
- `helm-docs` install script (checksum verification) unchanged
- `bump_skip_actors` logic unchanged
