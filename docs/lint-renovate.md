# lint-renovate.yml

Validation des fichiers de configuration Renovate via `renovate-config-validator --strict` : une config qui ne demande qu'une migration (option dépréciée) échoue aussi.

## Usage

```yaml
jobs:
  validate:
    uses: trowaflo/github-actions/.github/workflows/lint-renovate.yml@<sha> # vX.Y.Z
    permissions:
      contents: read
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — extra endpoints merged with defaults |
| `config_files` | string | `""` | Fichiers à valider, séparés par des espaces, globs développés par le shell (défaut : `*renovate*.json` et `*renovate*.json5` à la racine) |

`node_version` a disparu en v5.0.0 : le validateur tourne dans l'image Renovate, qui embarque son Node.

## Permissions requises

| Permission | Usage |
| --- | --- |
| `contents: read` | checkout |

## Secrets

Aucun.

## Image Renovate épinglée par digest

Le validateur tourne dans `ghcr.io/renovatebot/renovate:<version>@sha256:<digest>`, pas par `npm install --global renovate` : cette installation résolvait des centaines de paquets transitifs au moment du run, sans lockfile. Un lockfile commité ici ne servirait à rien, un workflow appelé ne voit que le checkout du caller. Le digest fige l'arbre entier, et Renovate met à jour tag et digest ensemble.

L'image est tirée à la mise en place du job, avant harden-runner : aucun registre n'entre dans l'allowlist, réduite à l'agent harden-runner, `api.github.com` et `github.com`.

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
