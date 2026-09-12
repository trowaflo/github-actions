# security.yml

Sécurité universelle. Les jobs de sécurité core sont **activés par défaut** (opt-out). Les scanners complémentaires sont **désactivés par défaut** (opt-in).

## Usage

```yaml
jobs:
  security:
    uses: trowaflo/github-actions/.github/workflows/security.yml@<sha> # vX.Y.Z
    permissions:
      contents: read
      pull-requests: write     # gitleaks annotations, dependency-review, KICS comments
      security-events: write   # SARIF uploads (kics, trivy, checkov)
    with:
      enable_dependency_review: true   # opt-in sur les PRs
      enable_checkov: true             # opt-in si IaC Terraform/K8s/Helm présent
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — extra endpoints merged with defaults |
| `enable_gitleaks` | boolean | `true` | Secret scanning avec gitleaks |
| `enable_kics` | boolean | `true` | Scan IaC avec KICS (SHA `05aa5eb` = v2.1.20, release officielle vérifiée post-TeamPCP) |
| `enable_dependency_review` | boolean | `false` | Revue CVE sur PR — **nécessite event `pull_request`** |
| `enable_checkov` | boolean | `false` | Scan IaC misconfigurations avec Checkov |
| `enable_trivy` | boolean | `false` | Scan IaC/filesystem avec Trivy |
| `checkov_framework` | string | `""` | Framework Checkov : `terraform`, `kubernetes`, `helm`, `dockerfile`, `""` = tout |
| `gitleaks_scan_mode` | string | `"event"` | Portée gitleaks : `event` (commits de l'event) ou `full` (historique complet) |
| `kics_fail_on` | string | `"high,medium"` | Sévérités KICS qui font échouer le job (`high`, `medium`, `low`, `info`) ; `""` n'échoue jamais |
| `trivy_severity` | string | `"UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"` | Niveaux de sévérité Trivy |

## Permissions requises

| Permission | Jobs qui l'utilisent |
| --- | --- |
| `contents: read` | Tous les jobs (checkout) |
| `pull-requests: write` | gitleaks (annotations), dependency-review, KICS (commentaires) |
| `security-events: write` | KICS, checkov, trivy (upload SARIF) |

## Secrets

Aucun — utilise `GITHUB_TOKEN` implicitement.

## Notes

### KICS

KICS est disponible via `enable_kics: true` (défaut).

**Depuis le 2026-09-12, le job barre.** `kics_fail_on` liste les sévérités qui font sortir KICS en code non nul, que l'action transforme en `core.setFailed()`. Le défaut est `high,medium` : `low` et `info` restent remontés en annotations, commentaire de PR et job summary, sans bloquer.

Avant cette date le workflow passait `ignore_on_exit: results`, qui force le code de sortie à zéro quelles que soient les trouvailles. Le job restait vert avec 15 findings dont 8 HIGH (mesuré sur `argocd`, run 34169168650). Les deux drapeaux sont exclusifs : `--ignore-on-exit results` écrase `--fail-on`.

Pour restaurer l'ancien comportement, sans blocage :

```yaml
with:
  kics_fail_on: ""     # annote, commente, résume, ne bloque jamais
```

Pour ne bloquer que sur HIGH :

```yaml
with:
  kics_fail_on: "high"
```

Sur un repo privé, l'upload SARIF est sauté (Code Scanning demande GHAS, payant). Le code de sortie est donc le **seul** signal bloquant : sans `kics_fail_on`, un repo privé n'a aucune application de ses findings IaC.

> ⚠ `checkmarx/kics-github-action` a été compromis lors de l'attaque supply chain TeamPCP (2026-03-23). Le SHA actuel est pinné sur un commit pré-incident (`v2.1.20`, 2026-03-04). Le SHA pinning protège contre le tag hijack.

### gitleaks, portée du scan

`gitleaks-action` déduit sa plage de commits de l'event :

| Event | Plage scannée |
| --- | --- |
| `pull_request` | `<premier commit de la PR>^..<dernier commit rendu par l'API>` |
| `push` d'un seul commit | ce commit (`--log-opts=-1`) |
| `push` de N commits | la plage poussée, plafonnée aux 20 commits du payload webhook |

Le piège est sur `pull_request` : l'action appelle `GET /repos/{owner}/{repo}/pulls/{n}/commits` **sans `per_page`**. Le défaut REST plafonne la page à 30. Une PR de 31 commits ou plus n'est donc scannée que jusqu'à son 30e, et le reste n'est jamais lu avant le merge.

Mesuré le 2026-09-12 sur `portfolio-sync` : la PR #2 porte 44 commits, l'endpoint en rend 30 ; la PR #1 en porte 40, il en rend 30. Une PR de 21 commits, elle, est bien scannée en entier (run 34571455867, `21 commits scanned`).

`gitleaks_scan_mode: full` supprime la plage et scanne tout l'historique. C'est la seule portée qui couvre une PR longue, et la seule qui voie l'historique antérieur à l'adoption de ce workflow.

```yaml
with:
  gitleaks_scan_mode: full
```

Le coût est réel : un secret déjà présent dans l'historique, tourné ou non, garde chaque run rouge jusqu'à ce que son empreinte entre dans `.gitleaksignore`. C'est pourquoi `event` reste le défaut.

Un `.gitleaks.toml` à la racine du repo caller est chargé et étendu par-dessus les règles par défaut dans les deux modes. Aucune licence n'est requise sur un compte individuel.

### Trivy (IaC)

`enable_trivy: true` lance un scan IaC/filesystem via `aquasecurity/trivy-action`. Par défaut, toutes les sévérités sont remontées (`UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL`). Configurable via `trivy_severity`. Ce scan est indépendant du scan container Trivy dans `ci-docker.yml`.

Les résultats sont uploadés au format SARIF dans l'onglet **Security > Code scanning** du repo, avec des annotations inline sur les PRs.

### dependency-review

Ce job ne s'exécute que si le workflow caller est déclenché par `pull_request`. Si activé depuis un workflow `push`, il sera automatiquement ignoré.

### checkov_framework

Par défaut, Checkov scanne tous les frameworks. Préciser le framework réduit le bruit sur des repos mono-technologie :

```yaml
with:
  enable_checkov: true
  checkov_framework: "terraform"
```

### harden-runner

[StepSecurity harden-runner](https://github.com/step-security/harden-runner) sécurise le réseau de chaque job. Depuis le 2026-08-14, la politique egress par défaut est `block` : tout trafic sortant hors allowlist est coupé. C'est la parade au vecteur TeamPCP, dont le canal d'exfiltration primaire était un POST vers un domaine tiers. Repasser à `audit` sur un repo dont les endpoints ne sont pas encore connus, jamais comme réglage durable.

Le workflow inclut une liste d'endpoints par défaut couvrant ses dépendances internes. Le consumer peut ajouter des endpoints via `harden_runner_allowed_endpoints` — ils sont **fusionnés** avec la liste par défaut.
