# security.yml

Sécurité universelle. Les jobs de sécurité core sont **activés par défaut** (opt-out). Les scanners complémentaires sont **désactivés par défaut** (opt-in).

## Usage

```yaml
jobs:
  security:
    uses: trowaflo/github-actions/.github/workflows/security.yml@<sha> # vX.Y.Z
    permissions:
      contents: read
      pull-requests: write     # gitleaks annotations, dependency-review, KICS comments
      security-events: write   # SARIF uploads (kics, trivy, checkov)
    with:
      enable_dependency_review: true   # opt-in sur les PRs
      enable_checkov: true             # opt-in si IaC Terraform/K8s/Helm présent
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"audit"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — extra endpoints merged with defaults |
| `enable_gitleaks` | boolean | `true` | Secret scanning avec gitleaks |
| `enable_kics` | boolean | `true` | Scan IaC avec KICS (⚠ TeamPCP 2026-03-23 — SHA pinné pré-incident) |
| `enable_dependency_review` | boolean | `false` | Revue CVE sur PR — **nécessite event `pull_request`** |
| `enable_checkov` | boolean | `false` | Scan IaC misconfigurations avec Checkov |
| `enable_trivy` | boolean | `false` | Scan IaC/filesystem avec Trivy |
| `checkov_framework` | string | `""` | Framework Checkov : `terraform`, `kubernetes`, `helm`, `dockerfile`, `""` = tout |
| `trivy_severity` | string | `"UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"` | Niveaux de sévérité Trivy |

## Permissions requises

| Permission | Jobs qui l'utilisent |
| --- | --- |
| `contents: read` | Tous les jobs (checkout) |
| `pull-requests: write` | gitleaks (annotations), dependency-review, KICS (commentaires) |
| `security-events: write` | KICS, checkov, trivy (upload SARIF) |

## Secrets

Aucun — utilise `GITHUB_TOKEN` implicitement.

## Notes

### KICS

KICS est disponible via `enable_kics: true` (défaut).

> ⚠ `checkmarx/kics-github-action` a été compromis lors de l'attaque supply chain TeamPCP (2026-03-23). Le SHA actuel est pinné sur un commit pré-incident (`v2.1.20`, 2026-03-04). Le SHA pinning protège contre le tag hijack.

### Trivy (IaC)

`enable_trivy: true` lance un scan IaC/filesystem via `aquasecurity/trivy-action`. Par défaut, toutes les sévérités sont remontées (`UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL`). Configurable via `trivy_severity`. Ce scan est indépendant du scan container Trivy dans `ci-docker.yml`.

Les résultats sont uploadés au format SARIF dans l'onglet **Security > Code scanning** du repo, avec des annotations inline sur les PRs.

### dependency-review

Ce job ne s'exécute que si le workflow caller est déclenché par `pull_request`. Si activé depuis un workflow `push`, il sera automatiquement ignoré.

### checkov_framework

Par défaut, Checkov scanne tous les frameworks. Préciser le framework réduit le bruit sur des repos mono-technologie :

```yaml
with:
  enable_checkov: true
  checkov_framework: "terraform"
```

### harden-runner

[StepSecurity harden-runner](https://github.com/step-security/harden-runner) sécurise le réseau de chaque job. Par défaut, la politique egress est `audit` — le trafic sortant est observé sans blocage. Passer à `block` une fois les endpoints connus.

Le workflow inclut une liste d'endpoints par défaut couvrant ses dépendances internes. Le consumer peut ajouter des endpoints via `harden_runner_allowed_endpoints` — ils sont **fusionnés** avec la liste par défaut.
