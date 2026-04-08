# release.yml

Release automatisée via release-please — crée des PRs de release et des tags sémantiques.

## Usage

```yaml
# Déclencher sur push vers main uniquement
on:
  push:
    branches:
      - main

jobs:
  release:
    uses: trowaflo/github-actions/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      enable_release_please: true
    secrets:
      release_token: ${{ secrets.RELEASE_TOKEN }}  # optionnel
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — extra endpoints merged with defaults |
| `enable_release_please` | boolean | `false` | Déclencher la création de PR release + tag |
| `release_config_file` | string | `""` | Chemin vers `release-please-config.json` (défaut : racine du repo) |
| `release_manifest_file` | string | `""` | Chemin vers `.release-please-manifest.json` (défaut : racine du repo) |

## Secrets

| Secret | Requis | Description |
| --- | --- | --- |
| `release_token` | Non | PAT pour créer des PRs — utilise `GITHUB_TOKEN` si absent |

## Notes

### release-please-config.json

Créer à la racine du repo :

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "simple",
  "packages": {
    ".": {
      "release-type": "simple",
      "changelog-path": "CHANGELOG.md"
    }
  }
}
```

### .release-please-manifest.json

Créer à la racine du repo (version de départ) :

```json
{
  ".": "0.0.0"
}
```

### Conventional commits

release-please lit les messages de commit pour déterminer le type de bump :

| Prefix | Bump |
| --- | --- |
| `feat:` | minor (`0.1.0 → 0.2.0`) |
| `fix:` | patch (`0.1.0 → 0.1.1`) |
| `feat!:` ou `BREAKING CHANGE:` | major (`0.1.0 → 1.0.0`) |

### GITHUB_TOKEN vs PAT

Le `GITHUB_TOKEN` par défaut ne peut pas déclencher d'autres workflows depuis la PR créée par release-please. Si vous avez des workflows qui doivent s'exécuter sur la PR de release, utiliser un PAT avec `release_token`.

### Versioning par workflow

release-please v4 gère le versioning par répertoire. Pour un versioning indépendant par workflow (ex : `quality-v1.2.0`, `ha-v0.3.0`), une restructuration du repo serait nécessaire (chaque workflow dans son propre sous-répertoire). À discuter si le besoin devient prioritaire.
