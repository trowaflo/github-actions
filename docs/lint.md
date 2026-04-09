# lint.yml

Lint et qualité de code. actionlint est **activé par défaut** (opt-out). Les autres linters sont **désactivés par défaut** (opt-in).

## Usage

```yaml
jobs:
  lint:
    uses: trowaflo/github-actions/.github/workflows/lint.yml@<sha> # vX.Y.Z
    permissions:
      contents: read
      security-events: write   # SARIF uploads (actionlint)
    with:
      enable_markdown_lint: true
      enable_yamllint: true
      enable_json_lint: true
      enable_ansible_lint: true   # opt-in pour les repos Ansible
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"audit"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — extra endpoints merged with defaults |
| `enable_actionlint` | boolean | `true` | Lint des fichiers workflow GitHub Actions |
| `enable_markdown_lint` | boolean | `false` | Lint Markdown avec markdownlint-cli2 |
| `enable_yamllint` | boolean | `false` | Lint YAML avec yamllint |
| `enable_json_lint` | boolean | `false` | Validation syntaxe JSON et JSON5 |
| `enable_ansible_lint` | boolean | `false` | Lint Ansible avec ansible-lint |
| `enable_terraform_validate` | boolean | `false` | `terraform fmt` + `tflint` |

## Permissions requises

| Permission | Jobs qui l'utilisent |
| --- | --- |
| `contents: read` | Tous les jobs (checkout) |
| `security-events: write` | actionlint (upload SARIF) |

## Secrets

Aucun — utilise `GITHUB_TOKEN` implicitement.

## Notes

### actionlint

Version gérée via Renovate (`datasource=github-releases depName=rhysd/actionlint`). Les binaires sont vérifiés par checksum SHA-256.

Les résultats sont uploadés au format SARIF — annotations inline sur les PRs.

### json_lint

Valide la syntaxe de tous les fichiers `*.json` (via `json.load`) et `*.json5` (via `json5.load`). Les fichiers dans `.git/` et `node_modules/` sont exclus.

### yamllint

Créer un `.yamllint.yml` à la racine du repo pour surcharger la configuration par défaut.

### harden-runner

[StepSecurity harden-runner](https://github.com/step-security/harden-runner) sécurise le réseau de chaque job. Par défaut, la politique egress est `audit` — le trafic sortant est observé sans blocage. Passer à `block` une fois les endpoints connus.
