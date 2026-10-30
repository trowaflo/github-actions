# E2.4 — Auditeur gouvernance

Modèle : Sonnet 5.5, effort medium.

## Mission

Vérifier que les règles décrites sont **imposées** et pas seulement écrites, et évaluer le passage à une organisation GitHub gratuite.

## Entrées

`brief-commun.md`, `OUT/e0/settings.jsonl`, `OUT/e1/`, repos `terraform-github`, `renovate-config`, ce repo.

## Questions

1. **Couverture Terraform** : quels repos et quels réglages sont gérés par `terraform-github` ? Lesquels ont dérivé (réglage réel ≠ Terraform) ? Lesquels sont hors Terraform ?
2. **Protection du repo central** : rulesets sur `main` et sur les tags, status checks requis, interdiction du force-push, qui peut créer un tag de release. Opérateur seul : une review obligatoire n'a pas de sens, des status checks obligatoires si. Que se passe-t-il si le compte est compromis ?
3. **Réglages Actions par repo** : permissions par défaut du token, droit d'approbation des PRs par Actions, actions autorisées (all / sélection), réglages fork. Homogènes ? Pilotés par Terraform ?
4. **Applications tierces** : Renovate, Claude, autres GitHub Apps installées : sur quels repos, avec quelles permissions. Strictement nécessaires ?
5. **Secrets** : inventaire des noms par repo, doublons d'un repo à l'autre, secrets probablement obsolètes, secrets remplaçables par OIDC.
6. **Renovate** : le preset central est-il réellement utilisé partout, des appelants le surchargent-ils (règles locales contraires à la contrainte 1) ?

## Migration vers une organisation gratuite

Chiffrer, sans recommander d'office. Vérifier les limites **actuelles** du plan Free d'organisation dans la documentation GitHub (ne pas se fier à sa mémoire, citer la page et la date) :

- Gains : policy d'actions autorisées centralisée, rulesets d'org, secrets et variables d'org, séparation compte perso / CI. Lesquels sont réellement disponibles sur repos privés en Free ?
- Coûts : quota de minutes (partagé ou additionnel ?), URLs qui changent (ArgoCD, Renovate, références `uses:`, GitHub Pages `trowaflo.github.io`, intégrations Home Assistant), redirections GitHub et leurs limites, apps à réinstaller, effort total.
- Alternative sans migration : ce que `terraform-github` permet déjà d'imposer repo par repo.

## Sorties dans `OUT/e2-4/`

- `findings.yaml` (préfixe `GOV`).
- `migration-org.md` : gains, coûts, alternative, verdict conditionnel (« oui si… », « non tant que… »), avec sources datées.
