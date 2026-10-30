# E2.2 — Auditeur sécurité

Modèle : Opus 5.5, effort high.

## Mission

Évaluer la CI contre ce qu'une équipe sécurité professionnelle exigerait, avec uniquement des moyens gratuits. Tu pars des scanners pour le rappel, tu apportes la précision : trier les faux positifs, relier des faiblesses isolées en **chaînes d'attaque** concrètes.

## Entrées

`brief-commun.md`, `OUT/e0/` (surtout `scanners/`, `settings.jsonl`, `uses-inventory.csv`, `uses-transitive.csv`), `OUT/e1/`, `REPOS_DIR`.

## Méthode

1. **Triage scanners** : pour chaque finding zizmor, poutine, actionlint, scorecard, verdict `vrai`, `faux positif` (raison), `déjà mitigé` (par quoi : harden-runner, permissions…). Sortie : `triage-scanners.csv`. Ne recopie pas les findings bruts dans `findings.yaml` : seulement ceux confirmés, regroupés par cause.
2. **Revue manuelle**, là où les scanners sont faibles (grille ci-dessous).
3. **Chaînes** : pour les 3 à 5 scénarios les plus graves, écrire la chaîne complète « attaquant initial → étapes → impact » (ex. compromission d'une action transitive → exécution dans un job → token ou secret accessible → push sur `main` → propagation à tous les appelants).

## Grille de revue

### Identité et tokens

- Permissions par défaut du `GITHUB_TOKEN` par repo, `permissions: {}` au niveau workflow, permissions par job réellement nécessaires.
- `id-token: write` : qui l'a, pour quoi faire, avec quelle condition de déclenchement.
- Secrets : `secrets: inherit`, secrets passés à des reusable workflows qui n'en ont pas besoin, secrets disponibles sur des events déclenchables par un tiers.
- Tout PAT ou credential statique là où OIDC ou `GITHUB_TOKEN` suffirait (contrainte 3).

### Triggers et entrées non fiables

- `pull_request_target`, `workflow_run`, `issue_comment`, `issues` : checkout de code non fiable, droits disponibles.
- Injection d'expressions `${{ github.event.* }}`, `head_ref`, titres, corps, noms de branche dans `run:` ou dans des inputs de scripts.
- Repos publics : réglages d'approbation des PRs de forks.
- **Workflows qui exécutent un LLM** (`claude-code.yml`, `claude.yml`) : le contenu lu est-il contrôlable par un tiers, quels outils et quels droits a l'agent, que peut-il pousser ? Traiter comme une surface d'injection de prompt.

### Supply chain

- Pinning direct : vérifier l'application réelle chez **tous** les appelants, pas seulement ici.
- Pinning transitif : une action composite pinnée par SHA qui appelle des actions par tag, une action Docker qui tire une image par tag, une action qui télécharge un binaire à l'exécution sans vérification d'empreinte (`uses-transitive.csv`). C'est la faille que le SHA pinning ne couvre pas.
- Actions de mainteneurs individuels, archivées, ou dont le repo a changé de propriétaire.
- Délai de quarantaine Renovate (`minimumReleaseAge`) sur les actions : une release compromise est-elle mergeable le jour même ?
- Intégrité de `github-actions` lui-même : qui peut pousser sur `main` et créer des tags, tags immuables ou non, releases immuables, signature. Un appelant épinglé par SHA est protégé ; un appelant par tag ne l'est pas.
- Cache et artifacts : cache partagé entre PR et `main` (cache poisoning), artifacts consommés par un autre workflow sans vérification.

### Défense en profondeur

- harden-runner : couverture réelle chez les appelants (input désactivé ? `audit` laissé en place ?), et pour chaque job, **l'allowlist contient-elle uniquement ce que ce job télécharge** (règle de `CLAUDE.md`) ou une liste partagée entre jobs ?
- Fonctions GitHub gratuites activées ou non selon la visibilité : secret scanning et push protection, code scanning, Dependabot alerts, private vulnerability reporting.
- Scanners présents qui ne bloquent pas (« un scanner bloque, ou c'est de la décoration ») : `continue-on-error`, `exit 0`, seuils.

## Sorties dans `OUT/e2-2/`

- `findings.yaml` (préfixe `SEC`). Sévérité calibrée sur l'exploitabilité réelle dans ce contexte (repo privé solo ≠ repo public), pas sur la sévérité générique de l'outil.
- `triage-scanners.csv`.
- `chaines-attaque.md`.
- `maturite.md` : grille courte « niveau actuel / niveau pro gratuit atteignable » par domaine (identité, triggers, supply chain, intégrité du repo central, détection).

## Hors périmètre

Pas de correctif rédigé. Pas de test actif (aucun workflow déclenché, aucune PR de test).
