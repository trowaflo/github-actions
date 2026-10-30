# E2.3 — Auditeur architecture, portabilité, versioning

Modèle : Opus 5.5, effort high.

## Mission

Répondre à une question de design : **quel modèle de CI partagée** permet à un opérateur seul de standardiser ~27 repos, de réagir vite à une supply chain attack, et de faire évoluer les versions sans que chaque changement coûte une vague de PRs et de minutes sur tous les repos.

Le diagnostic de départ de l'utilisateur, à confirmer ou infirmer : « un gros monolithe imbitable », et « monter de version sur le monobloc puis monter la version du monobloc partout n'aide pas ». La cause supposée n'est pas l'outil (reusable workflow vs composite action) mais la **granularité** et le **contrat de version**.

## Entrées

`brief-commun.md`, `OUT/e0/`, `OUT/e1/` (surtout `versioning-actuel.md`, `matrice-appelants.csv`), ce repo, `renovate-config`, `REPOS_DIR`.

## Diagnostic à produire

1. **Couplage** : quelles briques changent ensemble (historique git + CHANGELOG) ? Combien de releases de `github-actions` en 90 jours, et quelle part ne concernait qu'un seul workflow mais a fait bouger tous les appelants ?
2. **Coût d'un changement** de bout en bout : une action upstream bumpée → combien de PRs, de runs, de minutes, de jours avant que tous les appelants soient à jour ? Croiser avec E0 (`renovate-prs.csv`, `billing-by-event.csv`).
3. **Lisibilité** : taille et complexité des reusable workflows (`ci-helm.yml` ~770 lignes), nombre d'inputs, jobs conditionnés par `enable_*`. Un appelant comprend-il ce qui tourne chez lui ?
4. **Testabilité** : un changement dans un reusable workflow est-il testable sur un appelant réel en preview avant release ? Les `test-*.yml` couvrent-ils ce qui casse en vrai chez les appelants ?
5. **Dérive** : appelants en retard de version, CI locales qui contournent le modèle (`OUT/e1/graphe.md`).

## Options à comparer

Au moins 2, au plus 3 options cibles **réalistes**, dont le statu quo amélioré. Pistes à considérer, pas à imposer :

- Versioning par workflow dans le même repo (release-please multi-package, tags préfixés) vs un repo par famille.
- Découpage reusable workflows (orchestration, permissions, jobs) vs composite actions (étapes réutilisables dans un job, moins de jobs donc moins d'arrondi).
- Groupement et planification Renovate côté appelants (une PR groupée par semaine plutôt qu'une par release).
- **Kill-switch supply chain** : comment interdire une action ou une version en un point et en quelques heures sur tous les repos. Comparer au moins : bump central + propagation Renovate, règle Renovate centrale dans `renovate-config`, politique « actions autorisées » par repo pilotée par `terraform-github` (disponible sur compte perso, repo par repo), politique d'organisation (nécessite la migration évaluée en E2.4). Attention : toute liste de blocage lue **à l'exécution** depuis une branche mutable devient elle-même un vecteur d'attaque.

## Critères d'évaluation

Notés pour chaque option, avec justification :

| Critère | Mesure |
| --- | --- |
| Réaction supply chain | Heures entre advisory et tous les repos protégés ; actions manuelles nécessaires |
| Coût d'une montée de version | PRs + minutes CI par changement typique |
| Rayon d'impact d'une erreur | Combien de repos cassés par un mauvais release |
| Testabilité preview | Peut-on valider sur un appelant réel avant merge ? (contrainte 2) |
| Compatibilité contraintes | Renovate SHA sans auto-merge, pas de token longue durée, gratuit |
| Charge mentale | Ce qu'il faut savoir pour modifier sans casser |
| Coût de migration | Effort et risque pour y aller depuis l'existant |

## Sorties dans `OUT/e2-3/`

- `findings.yaml` (préfixe `ARCH`).
- `options.md` : diagnostic, options, tableau de critères, recommandation **tranchée** avec ses conditions de remise en cause.

## Hors périmètre

Pas d'implémentation, pas de YAML cible complet. Un extrait de 10 lignes pour illustrer un contrat de version est acceptable.
