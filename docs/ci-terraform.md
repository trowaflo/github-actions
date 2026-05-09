# ci-terraform.yml

Workflow Terraform réutilisable : `terraform validate / plan / apply`.

> **Note** : `terraform fmt` et `tflint` sont **volontairement absents**. Utilise [`lint.yml`](lint.md) avec `enable_terraform_validate: true` pour ces vérifications (pas de duplication).

## Usage

### Cas standard (HCP Terraform + SOPS)

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  pull_request:
    branches: [main]
    paths:
      - "terraform/**"
      - ".github/workflows/terraform.yml"
  push:
    branches: [main]
    paths:
      - "terraform/**"
      - ".github/workflows/terraform.yml"

permissions: {}

jobs:
  terraform:
    uses: trowaflo/github-actions/.github/workflows/ci-terraform.yml@<sha> # vX.Y.Z
    permissions:
      contents: read
      pull-requests: write
    with:
      working_directory: terraform
      terraform_version: 1.12.x
      enable_sops: true
      apply_environment: production
    secrets:
      tf_api_token: ${{ secrets.TF_API_TOKEN }}
      sops_age_key: ${{ secrets.SOPS_AGE_KEY }}
```

### Cas minimal (pas de SOPS, backend local ou autre)

```yaml
jobs:
  terraform:
    uses: trowaflo/github-actions/.github/workflows/ci-terraform.yml@<sha>
    permissions:
      contents: read
      pull-requests: write
    with:
      working_directory: terraform
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `apply_branch` | string | `"main"` | Branche sur laquelle l'apply tourne (event push) |
| `apply_environment` | string | `""` | GitHub Deployment Environment pour le job apply (vide = aucun) |
| `comment_plan_on_pr` | boolean | `true` | Poste le plan en commentaire sur la PR (PRs same-repo uniquement) |
| `enable_apply` | boolean | `true` | Lance `terraform apply` sur push de `apply_branch` |
| `enable_harden_runner` | boolean | `true` | Sécurité runtime via StepSecurity harden-runner |
| `enable_sops` | boolean | `false` | Configure SOPS avec une age key (secret `sops_age_key` requis si `true`) |
| `harden_runner_allowed_endpoints` | string | `""` | Endpoints supplémentaires (mergés avec les défauts, séparés par espaces) |
| `harden_runner_egress_policy` | string | `"audit"` | Politique egress : `audit` (observe) ou `block` (enforce) |
| `terraform_version` | string | `"1.12.x"` | Version Terraform (ou contrainte) |
| `working_directory` | string | `"."` | Dossier contenant le code Terraform |

## Secrets

| Secret | Required | Description |
| --- | --- | --- |
| `tf_api_token` | non | Token pour le backend Terraform (HCP TF / Terraform Cloud) |
| `sops_age_key` | non* | Clé privée age pour décryptage SOPS (*requis si `enable_sops: true`) |

## Permissions requises

| Permission | Jobs qui l'utilisent |
| --- | --- |
| `contents: read` | `plan`, `apply` (checkout) |
| `pull-requests: write` | `plan` (commentaire du plan sur la PR) |

## Comportement

### Job `plan` — sur `pull_request`

1. (optionnel) Harden Runner egress allowlist
2. (optionnel) Setup SOPS + age key
3. `terraform init`
4. `terraform validate`
5. `terraform plan -no-color -out=tfplan`
6. (optionnel, same-repo PR) Commente le plan sur la PR via `actions/github-script`

Le plan est tronqué à 60 000 caractères pour rester sous la limite GitHub. Le commentaire n'est posté que pour les PRs du même repo (pas les forks) afin d'éviter les fuites de plan vers des contributeurs externes.

### Job `apply` — sur `push` de `apply_branch`

1. (optionnel) Harden Runner
2. (optionnel) Setup SOPS
3. `terraform init`
4. `terraform apply -auto-approve`

L'`apply_environment` permet de gating l'apply derrière un Deployment Environment GitHub (manual approval, secrets scoped, etc.).

## Endpoints harden-runner par défaut

```text
agent.api.stepsecurity.io:443      — harden-runner agent
api.github.com:443                 — GitHub API (actions runtime, github-script)
app.terraform.io:443               — Terraform Cloud / HCP TF backend
checkpoint-api.hashicorp.com:443   — Terraform CLI version check
github.com:443                     — git clone, sops release
objects.githubusercontent.com:443  — release downloads
registry.terraform.io:443          — Terraform provider downloads
release-assets.githubusercontent.com:443 — Action releases
releases.hashicorp.com:443         — Terraform binary
```

Pour des providers ou registries privés, étendre via `harden_runner_allowed_endpoints`.

## Notes

- **Pas de fmt/tflint** : utilise `lint.yml` avec `enable_terraform_validate: true` en parallèle.
- **Pas de scan IaC** : utilise `security.yml` avec `enable_kics: true` (défaut) et/ou `enable_checkov: true` + `checkov_framework: "terraform"`.
- **Plan exit code** : le step `Terraform plan` propage l'exit code natif de Terraform (0 = no diff, 1 = error, 2 = diff present si `-detailed-exitcode`). Le commentaire PR est posté même en cas d'échec (`if: always()`).
