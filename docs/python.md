# python.yml

Python CI générique — tests pytest, lint ruff, couverture codecov.

Indépendant de tout framework : fonctionne pour n'importe quel projet Python. Pour un repo Home Assistant, passer les dépendances spécifiques via `extra_packages`.

## Usage

```yaml
jobs:
  python:
    uses: trowaflo/github-actions/.github/workflows/python.yml@<sha> # vX.Y.Z
    with:
      enable_test: true
      enable_lint: true
      coverage_path: "src/my_module"
    secrets:
      codecov_token: ${{ secrets.CODECOV_TOKEN }}
```

### Usage Home Assistant

```yaml
jobs:
  python:
    uses: trowaflo/github-actions/.github/workflows/python.yml@<sha> # vX.Y.Z
    with:
      enable_test: true
      enable_lint: true
      coverage_path: "custom_components/my_component"
      extra_packages: "pytest-homeassistant-custom-component==0.13.316"
    secrets:
      codecov_token: ${{ secrets.CODECOV_TOKEN }}
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `false` | Monitoring réseau via StepSecurity harden-runner (egress audit) |
| `enable_test` | boolean | `false` | Tests pytest + couverture codecov |
| `enable_lint` | boolean | `false` | Lint ruff |
| `python_version` | string | `"3.13"` | Version Python |
| `coverage_threshold` | string | `"80"` | Seuil de couverture minimum (%) |
| `test_path` | string | `"tests/"` | Répertoire des tests |
| `coverage_path` | string | `"."` | Chemin couvert par pytest-cov |
| `extra_packages` | string | `""` | Packages pip supplémentaires avant les tests |

## Secrets

| Secret | Requis | Description |
| --- | --- | --- |
| `codecov_token` | Non | Token Codecov — fonctionne sans pour les repos publics |

## Notes

### coverage_path

Correspond à l'argument `--cov=<path>` de pytest. Exemples :

- `"."` → tout le repo
- `"src/my_module"` → module spécifique
- `"custom_components/my_component"` → composant HA

### extra_packages

Permet d'injecter des dépendances de test sans modifier le workflow. Installés via `pip install` avant pytest. Exemple :

```yaml
extra_packages: "pytest-homeassistant-custom-component==0.13.316 pytest-asyncio==0.24.0"
```

### Versioning des dépendances

`pytest-homeassistant-custom-component` est lié aux releases HA. Mettre à jour manuellement lors des releases majeures. Renovate peut gérer cette dépendance si le manager `pip` est activé dans `renovate-config`.
