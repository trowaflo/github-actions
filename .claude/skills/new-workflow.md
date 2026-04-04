---
name: new-workflow
description: Scaffold a new reusable GitHub Actions workflow following trowaflo/github-actions conventions
triggers:
  - /new-workflow
---

# Skill: new-workflow

Use this skill to scaffold a new reusable workflow in this repo.

## Checklist

- [ ] Ask: what is the workflow's **domain** and **name** (e.g. `terraform.yml`)?
- [ ] Ask: what **jobs** should it contain? Which are opt-in vs default-on?
- [ ] Look up **current SHAs** for all external actions via `git ls-remote https://github.com/<owner>/<repo>.git 'refs/tags/*'`
- [ ] Create `.github/workflows/<name>.yml` using the template below
- [ ] Add the workflow to `ci.yml` if it should be called locally (security/quality workflows)
- [ ] Update `CLAUDE.md` inputs table for the new workflow
- [ ] Update `README.md` workflows table

## Template

```yaml
name: <Name>

# Reusable workflow — <description>
# Usage: uses: trowaflo/github-actions/.github/workflows/<name>.yml@<sha>
#
# <defaults philosophy: which jobs are true/false by default and why>

on:
  workflow_call:
    inputs:
      enable_<job>:
        description: "<description>"
        type: boolean
        default: <true|false>   # true = security/quality universal; false = domain-specific
      # ... max 10 inputs
    secrets:
      <secret_name>:
        description: "<description>"
        required: false
      # ... max 10 secrets

jobs:
  <job-name>:
    if: ${{ inputs.enable_<job> == true }}
    name: <Display Name>
    runs-on: ubuntu-latest
    permissions:
      contents: read   # minimal permissions
    steps:
      - uses: actions/checkout@<40-char-sha> # vX.Y.Z
      - uses: <owner>/<action>@<40-char-sha> # vX.Y.Z
```

## Rules

- ALL `uses:` must be pinned to a **40-char SHA** + version comment — never `@v4` or `@main`
- Conditional jobs: `if: ${{ inputs.enable_xxx == true }}` (not just `inputs.enable_xxx`)
- Permissions: declare minimal permissions per job (`contents: read` by default)
- Inputs: max 10 per workflow — use `string` type for config, `boolean` for feature flags
- Domain-specific → `default: false` ; Security/quality universal → `default: true`
- Never use `${{ github.event.* }}` directly in `run:` — always via `env:` variables
- Run `git ls-remote` to get SHAs — never guess or copy from old files without verifying

## SHA lookup pattern

```bash
git ls-remote https://github.com/<owner>/<repo>.git 'refs/tags/*' \
  | grep -v '\^{}' | sort -t'/' -k3 -V | tail -5
```

## After creation

1. Run `sha-check` mentally: grep all `uses:` — every external one must match `@[0-9a-f]{40}`
2. Commit with: `feat: add <name>.yml reusable workflow`
3. Push and open PR — `ci.yml` will validate via actionlint + sha-check
