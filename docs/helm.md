# helm.yml

Helm Charts CI/CD — release, lint, unit tests, docs, version bump, packages PR.

Tous les jobs sont **désactivés par défaut** (opt-in explicite).

## Usage

```yaml
# Lint sur les PRs
jobs:
  helm-ci:
    uses: trowaflo/github-actions/.github/workflows/helm.yml@<sha> # vX.Y.Z
    with:
      enable_lint: true
      enable_unittest: true
      enable_pr_charts: true
      charts_dir: "charts"
```

```yaml
# Release sur merge main
jobs:
  helm-release:
    uses: trowaflo/github-actions/.github/workflows/helm.yml@<sha> # vX.Y.Z
    with:
      enable_release: true
      charts_dir: "charts"
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_release` | boolean | `false` | Release via chart-releaser |
| `enable_lint` | boolean | `false` | Lint avec `ct lint` |
| `enable_unittest` | boolean | `false` | Unit tests avec helm-unittest |
| `enable_docs` | boolean | `false` | Génération doc avec helm-docs |
| `enable_bump` | boolean | `false` | Auto-bump de version des charts modifiés sur PR |
| `enable_pr_charts` | boolean | `false` | Package les charts modifiés et poste un commentaire de téléchargement |
| `enable_pr_cleanup` | boolean | `false` | Supprime les commentaires de charts après merge/fermeture PR |
| `charts_dir` | string | `"charts"` | Répertoire racine des charts |

## Secrets

Aucun — utilise `GITHUB_TOKEN` pour toutes les opérations.

## Notes

### enable_pr_charts et enable_pr_cleanup

Ces jobs ne s'exécutent que si l'event est `pull_request`. Ils seront ignorés sur `push`.

### helm-docs

Le job `enable_docs` crée un commit directement sur la branche courante. À utiliser dans un workflow déclenché par `pull_request` avec `contents: write`.

### helm-bump

Bumpe automatiquement la version `patch` des charts dont des fichiers ont changé dans la PR. Requiert que le workflow soit déclenché par `pull_request`.
