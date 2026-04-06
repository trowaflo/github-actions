# quality.yml

Sécurité + Linting universel. Les jobs de sécurité sont **activés par défaut** (opt-out). Les jobs domaine-spécifiques sont **désactivés par défaut** (opt-in).

## Usage

```yaml
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
      enable_gitleaks: true       # default — désactiver si besoin
      enable_checkov: true        # default — désactiver si besoin
      enable_actionlint: true     # default — désactiver si besoin
      enable_ansible_lint: true   # opt-in pour les repos Ansible
      enable_terraform_validate: true  # opt-in pour les repos Terraform
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `""` | Allowed endpoints when block (space-separated, e.g. `github.com:443`) |
| `enable_gitleaks` | boolean | `true` | Secret scanning avec gitleaks |
| `enable_checkov` | boolean | `true` | Scan IaC misconfigurations (remplace KICS) |
| `enable_actionlint` | boolean | `true` | Lint des fichiers workflow GitHub Actions |
| `enable_dependency_review` | boolean | `false` | Revue CVE sur PR — **nécessite event `pull_request`** |
| `enable_markdown_lint` | boolean | `false` | Lint Markdown avec markdownlint-cli2 |
| `enable_yamllint` | boolean | `false` | Lint YAML avec yamllint |
| `enable_ansible_lint` | boolean | `false` | Lint Ansible avec ansible-lint |
| `enable_terraform_validate` | boolean | `false` | `terraform fmt` + `tflint` |
| `enable_json_lint` | boolean | `false` | Validation syntaxe JSON et JSON5 |
| `enable_kics` | boolean | `false` | Scan IaC avec KICS (⚠ TeamPCP 2026-03-23 — préférer checkov) |
| `enable_trivy` | boolean | `false` | Scan IaC/filesystem avec Trivy |
| `checkov_framework` | string | `""` | Framework Checkov : `terraform`, `kubernetes`, `helm`, `dockerfile`, `""` = tout |
| `trivy_severity` | string | `"UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"` | Niveaux de sévérité Trivy |

## Secrets

Aucun — utilise `GITHUB_TOKEN` implicitement.

## Notes

### KICS

KICS est disponible via `enable_kics: true`. Le fichier `kics.yml` standalone a été supprimé.

> ⚠ `checkmarx/kics-github-action` a été compromis lors de l'attaque supply chain TeamPCP (2026-03-23). **Préférer `enable_checkov`** sauf besoin spécifique.

### Trivy (IaC)

`enable_trivy: true` lance un scan IaC/filesystem via `aquasecurity/trivy-action`. Par défaut, toutes les sévérités sont remontées (`UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL`). Configurable via `trivy_severity`. Ce scan est indépendant du scan container Trivy dans `docker.yml`.

Les résultats sont uploadés au format SARIF dans l'onglet **Security > Code scanning** du repo, avec des annotations inline sur les PRs.

### dependency-review

Ce job ne s'exécute que si le workflow caller est déclenché par `pull_request`. Si activé depuis un workflow `push`, il sera automatiquement ignoré.

### yamllint

Créer un `.yamllint.yml` à la racine du repo pour surcharger la configuration par défaut.

### checkov_framework

Par défaut, Checkov scanne tous les frameworks. Préciser le framework réduit le bruit sur des repos mono-technologie :

```yaml
with:
  enable_checkov: true
  checkov_framework: "terraform"
```

Les résultats sont uploadés au format SARIF dans l'onglet **Security > Code scanning** du repo, avec des annotations inline sur les PRs.

### harden-runner

[StepSecurity harden-runner](https://github.com/step-security/harden-runner) sécurise le réseau de chaque job. Par défaut, la politique egress est `block` — tout le trafic sortant est interdit sauf les endpoints explicitement autorisés via `harden_runner_allowed_endpoints`.

Pour découvrir les endpoints nécessaires, commencer avec `harden_runner_egress_policy: audit` puis passer à `block` avec la liste d'endpoints identifiés.
