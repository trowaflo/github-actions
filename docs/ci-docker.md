# ci-docker.yml

Docker Build & Container Scanning — build/push via bake, CVE scanning avec Trivy.

Tous les jobs sont **désactivés par défaut** (opt-in explicite).

## Ordre d'exécution

Le workflow garantit l'ordre **build → scan → publish** :

1. Build l'image avec un tag staging temporaire (`:scan-{run_id}`)
2. Scan Trivy sur ce tag staging
3. Si le scan passe : publish final avec les tags définis dans le bake file
4. Si le scan échoue : le job s'arrête — **le publish n'a pas lieu**

Le tag staging (`:scan-{run_id}`) reste dans le registre après le workflow. Il peut être nettoyé par des politiques de rétention du registre (ghcr.io : 90 jours pour les packages non utilisés).

## Usage

```yaml
jobs:
  docker:
    uses: trowaflo/github-actions/.github/workflows/ci-docker.yml@<sha> # vX.Y.Z
    with:
      enable_trivy: true
    secrets:
      registry_username: ${{ secrets.REGISTRY_USER }}    # optionnel pour ghcr.io
      registry_password: ${{ secrets.REGISTRY_TOKEN }}   # optionnel pour ghcr.io
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"audit"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — extra endpoints merged with defaults |
| `enable_trivy` | boolean | `false` | CVE scan via Trivy (aquasecurity) |
| `registry` | string | `"ghcr.io"` | Registre Docker cible |
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

### ghcr.io

Pour pousser vers `ghcr.io`, aucun secret nécessaire si le repo est dans la même organisation GitHub. Le `GITHUB_TOKEN` suffit avec la permission `packages: write`.
