# Helm Workflows

Helm Charts CI/CD — split into three focused reusable workflows.

Tous les jobs sont **désactivés par défaut** (opt-in explicite), sauf `helm-pr-cleanup` qui
s'active dès que le workflow est appelé sur un événement `pull_request closed`.

---

## helm-ci.yml — Pull Request CI

Lint, tests, bump de version, génération de docs, et packaging PR.

**Ordre d'exécution :**

```
lint + unittest → bump → docs → docs-check
                      └──────────────→ pr-charts
```

### Usage

```yaml
jobs:
  helm-ci:
    uses: trowaflo/github-actions/.github/workflows/helm-ci.yml@<sha> # vX.Y.Z
    permissions:
      contents: write
      checks: write
      pull-requests: write
    with:
      enable_lint: true
      enable_unittest: true
      enable_bump: true
      enable_docs: true
      enable_docs_check: true
      enable_pr_charts: true
      charts_dir: "charts"
```

### Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` or `block` |
| `harden_runner_allowed_endpoints` | string | (built-in) | Extra endpoints merged with defaults |
| `enable_lint` | boolean | `false` | Lint avec `ct lint` |
| `enable_unittest` | boolean | `false` | Unit tests avec helm-unittest |
| `enable_bump` | boolean | `false` | Auto-bump de version des charts modifiés sur PR |
| `enable_docs` | boolean | `false` | Génération doc avec helm-docs (après bump) |
| `enable_docs_check` | boolean | `false` | Valide que les docs sont à jour |
| `enable_pr_charts` | boolean | `false` | Package les charts modifiés et poste un commentaire |
| `charts_dir` | string | `"charts"` | Répertoire racine des charts |
| `bump_skip_actors` | string | `"renovate[bot]"` | Acteurs à ignorer pour le bump |

---

## helm-release.yml — Release

Release des charts via chart-releaser (push sur main).

### Usage

```yaml
jobs:
  helm-release:
    uses: trowaflo/github-actions/.github/workflows/helm-release.yml@<sha> # vX.Y.Z
    permissions:
      contents: write
      pages: write
    with:
      enable_release: true
      charts_dir: "charts"
```

### Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` or `block` |
| `harden_runner_allowed_endpoints` | string | (built-in) | Extra endpoints merged with defaults |
| `enable_release` | boolean | `false` | Release via chart-releaser |
| `charts_dir` | string | `"charts"` | Répertoire racine des charts |
| `release_charts_dirs` | string | `""` | Répertoires de charts à releaser (max 2, space-separated) |

---

## helm-pr-cleanup.yml — PR Cleanup

Supprime les charts PR de la branche `pr-charts` quand une PR est mergée ou fermée.

Pas de flag — appeler ce workflow implique l'intention de cleanup.

### Usage

```yaml
jobs:
  helm-pr-cleanup:
    uses: trowaflo/github-actions/.github/workflows/helm-pr-cleanup.yml@<sha> # vX.Y.Z
    permissions:
      contents: write
      pull-requests: write
```

### Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` or `block` |
| `harden_runner_allowed_endpoints` | string | (built-in) | Extra endpoints merged with defaults |

---

## Secrets

Aucun — utilise `GITHUB_TOKEN` pour toutes les opérations.
