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
| `gitleaks_scan_mode` | string | `"full"` | Portée gitleaks : `full` (historique complet) ou `event` (commits de l'event seulement) |
| `kics_fail_on` | string | `"high,medium,low"` | Sévérités KICS qui font échouer le job (`high`, `medium`, `low`, `info`) ; `""` n'échoue jamais |
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

**Depuis le 2026-09-12, le job barre.** `kics_fail_on` liste les sévérités qui font sortir KICS en code non nul, que l'action transforme en `core.setFailed()`. Le défaut est `high,medium,low`. `info` reste remonté en annotations, commentaire de PR et job summary, sans bloquer.

Le partage se fait sur un critère, pas sur un volume. Les findings `low` mesurés sur les appelants sont des points de durcissement : `Image Without Digest`, `Secrets As Environment Variables`, `No Drop Capabilities for Containers`, `Root Container Not Mounted Read-only`, `Missing AppArmor Profile`. Les findings `info` sont de l'hygiène d'exploitation : `Liveness Probe Is Not Defined`, `Pod or Container Without LimitRange`, `Ensure Administrative Boundaries Between Resources`. Une sonde de vie manquante n'a pas sa place dans une barrière de sécurité.

Chiffres du 2026-09-12 sur les appelants lisibles : 13 findings `low` et 4 `info`, répartis sur trois dépôts qui sont **déjà** rouges en `high` ou `medium`. Barrer sur `low` ne met donc aucun appelant supplémentaire au rouge aujourd'hui.

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

`gitleaks_scan_mode: full` ajoute une seconde passe sans aucune plage, qui lit tout l'historique. C'est la seule portée qui couvre une PR longue, et la seule qui voie l'historique antérieur à l'adoption de ce workflow. Elle n'installe rien : l'action pose son binaire sur le `PATH` du job, la passe complète réutilise le même exécutable au même SHA.

Les annotations, le commentaire de PR et le job summary restent produits par l'action, donc par la passe event. La passe complète ne parle que dans les logs et par son code de sortie.

```yaml
with:
  gitleaks_scan_mode: full
```

Le coût de run est négligeable, mesuré le 2026-09-12 sur les plus gros historiques d'appelants : 6,3 s pour `argocd` (1393 commits scannés), 12,5 s pour `home-assistant` (916), 5,8 s pour `helm-charts` (764).

Le coût réel est ailleurs : un secret déjà présent dans l'historique garde chaque run rouge tant qu'il n'est pas retiré de l'historique. C'est de la remédiation, pas du bruit, et c'est la raison d'être du mode. Un appelant qui a besoin de temps pose `gitleaks_scan_mode: event` explicitement, avec son motif.

Un `.gitleaks.toml` à la racine du repo caller est chargé et étendu par-dessus les règles par défaut dans les deux modes. Aucune licence n'est requise sur un compte individuel.

### Ce que la garde gitleaks ne couvre pas

**Un secret chiffré au repos est invisible pour le scanner, par conception.** `home-assistant` chiffre son `secrets.yaml` avec [git-crypt](https://github.com/AGWA/git-crypt). Sur un runner, qui clone sans la clé, `git log -p` ne rend que le blob chiffré : gitleaks ne trouve rien, et le job est vert. Depuis un poste déverrouillé, le même scan sur le même commit trouve un `slack-bot-token`. Mesuré le 2026-09-12 sur le commit `409cf57f`, les deux résultats, même binaire et même configuration.

Ce n'est pas un défaut du scanner. C'est le partage des rôles : **git-crypt protège, gitleaks surveille ce qui n'est pas protégé.** Mais un vert sur cette garde ne veut donc pas dire « ce dépôt ne contient aucun secret », il veut dire « aucun secret en clair dans ce qui a été scanné ». Sur un dépôt qui chiffre, la question de la rotation des clés et de la gestion des accès reste entière et ne sera jamais posée par cette CI.

Corollaire pratique : ne jamais mesurer l'exposition d'un dépôt depuis un poste déverrouillé, le chiffre sera faux dans un sens comme dans l'autre. La mesure de référence se prend sur un clone frais, ce que fait `actions/checkout`.

### Portée d'un scan, une ref n'est pas une branche

La passe `full` lance `gitleaks detect` sans `--log-opts`, donc elle **atteint toutes les refs récupérées**, pas seulement la branche par défaut. C'est voulu, et c'est ce qui la distingue :

- `portfolio-sync` rend **zéro** trouvaille sur `origin/main` et **59** toutes refs, toutes portées par un tag `backup/pre-history-purge` laissé après une réécriture d'historique ;
- `argocd` rend **1** sur le tronc et **4** toutes refs, les trois autres vivant sur deux branches abandonnées.

Un secret sur une ref oubliée est exposé exactement comme un secret sur le tronc : `git clone` la récupère. La portée `event` ne la regarde jamais.

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
