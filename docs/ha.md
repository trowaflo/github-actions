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

### Config check avec secrets et custom components

```yaml
jobs:
  ha:
    uses: trowaflo/github-actions/.github/workflows/ha.yml@<sha> # vX.Y.Z
    with:
      enable_config_check: true
      ha_version: "2026.3.4"
      config_check_secrets: secrets.fake.yaml
      config_check_setup: |
        mkdir -p custom_components
        curl -sL https://github.com/ScratMan/HASmartThermostat/archive/refs/heads/master.tar.gz \
          | tar xz --strip-components=1 -C . 'HASmartThermostat-master/custom_components/'
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_hacs` | boolean | `false` | Validation HACS |
| `enable_hassfest` | boolean | `false` | Validation hassfest |
| `enable_config_check` | boolean | `false` | HA config check |
| `ha_version` | string | `""` | Version HA — **requis** si `enable_config_check: true` (e.g. `2026.3.4`, `stable`, `beta`) |
| `config_check_secrets` | string | `""` | Chemin vers un fichier secrets pour le config check (e.g. `secrets.fake.yaml`) |
| `config_check_setup` | string | `""` | Commandes shell à exécuter avant le config check (e.g. installer des custom components) |

## Notes

### Tests Python

Les tests pytest et le lint ruff ont été extraits dans [`python.yml`](python.md). Ce workflow se concentre sur les validations spécifiques à l'écosystème HA (HACS, hassfest, config check).

### hassfest

Valide la structure du composant custom (`manifest.json`, traductions, etc.) contre les règles de Home Assistant. Tourne en `master` de `home-assistant/actions/hassfest` — SHA mis à jour par Renovate.

### HA config check

Lance HA en mode minimal pour vérifier la syntaxe de la configuration YAML. Requiert `ha_version` pour reproduire fidèlement l'environnement cible.

### config_check_secrets

Permet de passer un fichier secrets factice (e.g. `secrets.fake.yaml`) à l'action frenck. Utile quand les vrais secrets sont chiffrés (git-crypt) et non disponibles en CI. Le fichier doit exister dans le repo ou être créé via `config_check_setup`.

### config_check_setup

Commandes shell exécutées après le checkout et avant le config check. Cas d'usage typiques :

- Installer des custom components HACS nécessaires à la validation
- Créer un fichier secrets factice
- Copier des fichiers de configuration conditionnels
