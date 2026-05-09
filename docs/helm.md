# Helm Workflows

Helm Charts CI/CD — split into three focused reusable workflows.

Tous les jobs sont **désactivés par défaut** (opt-in explicite), sauf `ci-helm-cleanup` qui
s'active dès que le workflow est appelé sur un événement `pull_request closed`.

---

## ci-helm.yml — Pull Request CI

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
    uses: trowaflo/github-actions/.github/workflows/ci-helm.yml@<sha> # vX.Y.Z
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
| `harden_runner_egress_policy` | string | `"audit"` | Egress policy: `audit` or `block` |
| `harden_runner_allowed_endpoints` | string | (built-in) | Extra endpoints merged with defaults |
| `enable_lint` | boolean | `false` | Lint avec `ct lint` |
| `enable_unittest` | boolean | `false` | Unit tests avec helm-unittest |
| `enable_bump` | boolean | `false` | Auto-bump de version des charts modifiés sur PR |
| `enable_docs` | boolean | `false` | Génération doc avec helm-docs (après bump) |
| `enable_docs_check` | boolean | `false` | Valide que les docs sont à jour |
| `enable_pr_charts` | boolean | `false` | Package les charts modifiés et publie sur la branche `pr-charts` |
| `enable_oci_pr_charts` | boolean | `false` | Publie aussi sur GHCR OCI (`oci://ghcr.io/<owner>/<repo>/<chart>`). Indépendant de `enable_pr_charts` — activer les deux pour dual-publish |
| `charts_dir` | string | `"charts"` | Répertoire racine des charts |
| `bump_skip_actors` | string | `"renovate[bot]"` | Acteurs à ignorer pour le bump |

### Permissions requises pour `enable_oci_pr_charts`

Le job déclare déjà `packages: write`. Côté consumer, ajouter :

```yaml
permissions:
  contents: write
  packages: write       # publication OCI sur GHCR
  pull-requests: write
  checks: write
```

---

## release-helm.yml — Release

Release des charts via chart-releaser (push sur main).

### Usage

```yaml
jobs:
  helm-release:
    uses: trowaflo/github-actions/.github/workflows/release-helm.yml@<sha> # vX.Y.Z
    permissions:
      contents: write
      pages: write
    with:
      enable_release: true
```

### Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"audit"` | Egress policy: `audit` or `block` |
| `harden_runner_allowed_endpoints` | string | (built-in) | Extra endpoints merged with defaults |
| `enable_release` | boolean | `false` | Release via chart-releaser |
| `release_charts_dirs` | string | `""` | Répertoires de charts à releaser (max 2, space-separated). Defaults to `charts` |

---

## ci-helm-cleanup.yml — PR Cleanup

Supprime les charts PR de la branche `pr-charts` quand une PR est mergée ou fermée.

Pas de flag — appeler ce workflow implique l'intention de cleanup.

**Réconciliation auto** : à chaque exécution, le workflow scanne tous les `*-pr<N>.tgz`
présents sur la branche et supprime ceux dont le PR est `closed` (mergé ou non),
pas seulement le PR courant. Cela rattrape automatiquement les orphelins issus
de runs précédents qui auraient échoué (ex. egress block, runner indisponible).
La branche est uniquement modifiée si au moins un orphelin a été retiré.

### Usage

```yaml
jobs:
  helm-pr-cleanup:
    uses: trowaflo/github-actions/.github/workflows/ci-helm-cleanup.yml@<sha> # vX.Y.Z
    permissions:
      contents: write
      pull-requests: write
```

### Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"audit"` | Egress policy: `audit` or `block` |
| `harden_runner_allowed_endpoints` | string | (built-in) | Extra endpoints merged with defaults |
| `enable_oci_cleanup` | boolean | `false` | Supprime aussi les versions OCI taguées `*-pr<N>` sur GHCR pour les PRs closed |

### OCI cleanup — limité aux repos user-owned et scopé par repo

**Limite owner** : le step ne traite **que** les comptes user-owned. Si l'owner est une
Organization, le step émet un `::warning::` et skip — pour ne pas toucher de packages
d'orgs avec un workflow qui n'a été validé que sur du user-owned.

**Limite scope (lié au format de publication)** : le job `helm-pr-charts` publie en
`oci://ghcr.io/<owner>/<repo>/<chart>`, ce qui crée des packages GHCR nommés
`<repo>/<chart>`. Le cleanup filtre **strictement** sur le préfixe `<repo>/` du repo
courant — il ne touche jamais aux packages d'un autre repo du même owner, même si un
chart d'un autre repo a un tag `*-pr<N>` qui collide avec un PR fermé du repo courant.

> ⚠️ Si tu as historiquement publié des charts en `oci://ghcr.io/<owner>/<chart>` (sans
> namespace repo), ces packages legacy ne seront **pas** matchés par le filtre actuel —
> ils doivent être nettoyés manuellement. Tous les charts publiés via la version
> namespacée tombent dans le bon scope.

Pour les **user-owned repos** : l'API `/user/packages/...` requiert un PAT avec scope `delete:packages`.
Fournir le PAT via `secrets.OCI_CLEANUP_TOKEN` :

```yaml
jobs:
  helm-pr-cleanup:
    uses: trowaflo/github-actions/.github/workflows/ci-helm-cleanup.yml@<sha>
    permissions:
      contents: write
      packages: write
      pull-requests: write
    with:
      enable_oci_cleanup: true
    secrets:
      OCI_CLEANUP_TOKEN: ${{ secrets.GHCR_DELETE_PAT }}
```

Sans PAT sur un user-owned repo, le step émet un `::warning::` mais ne casse pas le workflow.

---

## Secrets

| Secret | Workflow | Required | Description |
| --- | --- | --- | --- |
| `OCI_CLEANUP_TOKEN` | `ci-helm-cleanup.yml` | Optional | PAT avec `delete:packages` — uniquement requis pour user-owned repos quand `enable_oci_cleanup: true` |
