# validate-renovate.yml

Validation des fichiers de configuration Renovate via `renovate-config-validator`.

## Usage

```yaml
jobs:
  validate:
    uses: trowaflo/github-actions/.github/workflows/validate-renovate.yml@<sha> # vX.Y.Z
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `false` | Monitoring réseau via StepSecurity harden-runner |
| `node_version` | string | `"22"` | Version de Node.js |
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

### Combinaison avec quality.yml

Pour une validation complète, combiner avec `quality.yml` et `enable_json_lint: true` :

```yaml
jobs:
  quality:
    uses: trowaflo/github-actions/.github/workflows/quality.yml@<sha>
    with:
      enable_json_lint: true

  validate-renovate:
    uses: trowaflo/github-actions/.github/workflows/validate-renovate.yml@<sha>
```

`enable_json_lint` vérifie la syntaxe JSON/JSON5, `validate-renovate` vérifie la sémantique Renovate.
