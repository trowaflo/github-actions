# quality.yml

Sécurité + Linting universel. Les jobs de sécurité sont **activés par défaut** (opt-out). Les jobs domaine-spécifiques sont **désactivés par défaut** (opt-in).

## Usage

```yaml
jobs:
  quality:
    uses: trowaflo/github-actions/.github/workflows/quality.yml@<sha> # vX.Y.Z
    with:
      enable_gitleaks: true       # default — désactiver si besoin
      enable_checkov: true        # default — désactiver si besoin
      enable_actionlint: true     # default — désactiver si besoin
      enable_ansible_lint: true   # opt-in pour les repos Ansible
      enable_terraform_validate: true  # opt-in pour les repos Terraform
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- |--- |
| `enable_gitleaks` | boolean | `true` | Secret scanning avec gitleaks |
| `enable_checkov` | boolean | `true` | Scan IaC misconfigurations (remplace KICS) |
| `enable_actionlint` | boolean | `true` | Lint des fichiers workflow GitHub Actions |
| `enable_dependency_review` | boolean | `false` | Revue CVE sur PR — **nécessite event `pull_request`** |
| `enable_markdown_lint` | boolean | `false` | Lint Markdown avec markdownlint-cli2 |
| `enable_yamllint` | boolean | `false` | Lint YAML avec yamllint |
| `enable_ansible_lint` | boolean | `false` | Lint Ansible avec ansible-lint |
| `enable_terraform_validate` | boolean | `false` | `terraform fmt` + `tflint` |
| `checkov_framework` | string | `""` | Framework Checkov : `terraform`, `kubernetes`, `helm`, `dockerfile`, `""` = tout |

## Secrets

Aucun — utilise `GITHUB_TOKEN` implicitement.

## Notes

### KICS

KICS (`checkmarx/kics-github-action`) est **définitivement remplacé** par Checkov. Il a été compromis lors de l'attaque supply chain TeamPCP (2026-03-23). Ne pas le réactiver.

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
