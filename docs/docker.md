# docker.yml

Docker Build & Container Scanning — build/push via bake, CVE scanning avec Trivy et grype.

Tous les jobs sont **désactivés par défaut** (opt-in explicite).

## Ordre d'exécution

Quand `enable_build: true`, le workflow garantit l'ordre **build → scan → publish** :

1. Build l'image avec un tag staging temporaire (`:scan-{run_id}`)
2. Scan Trivy et/ou grype sur ce tag staging
3. Si tous les scans passent : publish final avec les tags définis dans le bake file
4. Si un scan échoue : le job s'arrête — **le publish n'a pas lieu**

Le tag staging (`:scan-{run_id}`) reste dans le registre après le workflow. Il peut être nettoyé par des politiques de rétention du registre (ghcr.io : 90 jours pour les packages non utilisés).

## Usage

### Build + scan (recommandé)

```yaml
jobs:
  docker:
    uses: trowaflo/github-actions/.github/workflows/docker.yml@<sha> # vX.Y.Z
    with:
      enable_build: true
      enable_trivy: true
      enable_grype: true
    secrets:
      registry_username: ${{ secrets.REGISTRY_USER }}    # optionnel pour ghcr.io
      registry_password: ${{ secrets.REGISTRY_TOKEN }}   # optionnel pour ghcr.io
```

### Scan uniquement (image existante)

Mode `enable_build: false` : scanner une image déjà dans le registre, sans rebuilder.

Deux cas d'usage principaux :

- **Scan planifié** — détecter les nouvelles CVEs sur des images en production, sans attendre un nouveau build. Une CVE publiée aujourd'hui peut affecter une image buildée il y a 2 semaines.
- **Scan de base image** — vérifier une image tierce (`nginx:alpine`, `python:3.13-slim`) avant de builder dessus.

```yaml
# Scan quotidien sur les images en production
on:
  schedule:
    - cron: '0 6 * * *'

jobs:
  docker:
    uses: trowaflo/github-actions/.github/workflows/docker.yml@<sha> # vX.Y.Z
    with:
      enable_trivy: true
      enable_grype: true
      image_name: "ghcr.io/trowaflo/my-image:latest"
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `""` | Allowed endpoints when block (space-separated) |
| `enable_build` | boolean | `false` | Docker build & push via bake |
| `enable_trivy` | boolean | `false` | CVE scan via Trivy (aquasecurity) |
| `enable_grype` | boolean | `false` | CVE scan via grype (Anchore/Cisco) |
| `registry` | string | `"ghcr.io"` | Registre Docker cible |
| `image_name` | string | `""` | Nom de l'image — défaut : `{registry}/{github.repository}` |
| `trivy_severity` | string | `""` | Sévérités Trivy à remonter (vide = toutes) |

## Secrets

| Secret | Requis | Description |
| --- | --- | --- |
| `registry_username` | Non | Username — utilise `github.actor` pour ghcr.io si absent |
| `registry_password` | Non | Password — utilise `GITHUB_TOKEN` pour ghcr.io si absent |

## Notes

### Bake file

Ce workflow délègue entièrement au `docker-bake.hcl` (ou `compose.yml`) du repo consumer. Le workflow ne contrôle pas les tags finaux, les platforms, ni les targets — tout est dans le bake file. Le build staging utilise `set: "*.tags=staging-tag"` pour forcer un tag temporaire sur tous les targets.

### Multi-platform

QEMU est configuré automatiquement. Les platforms cibles sont définies dans le bake file du consumer.

### Trivy vs grype

Les deux scanners sont indépendants et complémentaires :

| | Trivy | grype |
| --- | --- | --- |
| Éditeur | aquasecurity | Anchore (Cisco) |
| Base de données | NVD, GitHub Advisory, OS advisories | Grype DB (NVD + OS) |

Activer les deux permet de comparer la couverture dans le temps.

### ghcr.io

Pour pousser vers `ghcr.io`, aucun secret nécessaire si le repo est dans la même organisation GitHub. Le `GITHUB_TOKEN` suffit avec la permission `packages: write`.
