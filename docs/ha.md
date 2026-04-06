# ha.yml

Home Assistant CI — validation HACS, hassfest, config check.

Tous les jobs sont **désactivés par défaut** (opt-in explicite).

> **Tests Python et lint** : utiliser [`python.yml`](python.md) avec `extra_packages: "pytest-homeassistant-custom-component==0.13.316"`.

## Usage

```yaml
jobs:
  ha:
    uses: trowaflo/github-actions/.github/workflows/ha.yml@<sha> # vX.Y.Z
    with:
      enable_hacs: true
      enable_hassfest: true

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
| `enable_hacs` | boolean | `false` | Validation HACS |
| `enable_hassfest` | boolean | `false` | Validation hassfest |
| `enable_config_check` | boolean | `false` | HA config check |
| `ha_version` | string | `""` | Version HA — **requis** si `enable_config_check: true` |

## Notes

### Tests Python

Les tests pytest et le lint ruff ont été extraits dans [`python.yml`](python.md). Ce workflow se concentre sur les validations spécifiques à l'écosystème HA (HACS, hassfest, config check).

### hassfest

Valide la structure du composant custom (`manifest.json`, traductions, etc.) contre les règles de Home Assistant. Tourne en `master` de `home-assistant/actions/hassfest` — SHA mis à jour par Renovate.

### HA config check

Lance HA en mode minimal pour vérifier la syntaxe de la configuration YAML. Requiert `ha_version` pour reproduire fidèlement l'environnement cible.
