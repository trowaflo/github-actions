# lint-renovate.yml

Validation des fichiers de configuration Renovate via `renovate-config-validator`.

## Usage

```yaml
jobs:
  validate:
    uses: trowaflo/github-actions/.github/workflows/lint-renovate.yml@<sha> # vX.Y.Z
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"audit"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — extra endpoints merged with defaults |
| `node_version` | string | `"24"` | Version de Node.js |
| `config_files` | string | `""` | Glob pattern des fichiers à valider (défaut : `*.json *.json5` à la racine) |

## Secrets

Aucun — utilise `GITHUB_TOKEN` implicitement.

## Notes

### Fichiers validés

Par défaut, le workflow valide tous les fichiers `*.json` et `*.json5` à la racine du repo. Personnaliser avec `config_files` :

```yaml
with:
  config_files: "renovate/*.json5 config/renovate.json"
```

### Combinaison avec security.yml + lint.yml

Pour une validation complète, combiner avec `lint.yml` et `enable_json_lint: true` :

```yaml
jobs:
  lint:
    uses: trowaflo/github-actions/.github/workflows/lint.yml@<sha>
    with:
      enable_json_lint: true

  lint-renovate:
    uses: trowaflo/github-actions/.github/workflows/lint-renovate.yml@<sha>
```

`enable_json_lint` vérifie la syntaxe JSON/JSON5, `lint-renovate` vérifie la sémantique Renovate.
