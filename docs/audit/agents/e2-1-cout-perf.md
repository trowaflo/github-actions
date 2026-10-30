# E2.1 — Auditeur coût / performance

Modèle : Sonnet 5.5, effort high.

## Mission

Expliquer où partent les minutes et proposer de quoi repasser durablement sous les 2000 min/mois, **sans retirer de garde-fou de sécurité** sans le dire explicitement.

## Entrées

`brief-commun.md`, `DATA/e0/` (surtout `billing-by-*.csv`, `jobs.jsonl`, `renovate-prs.csv`, `storage.csv`), `OUT/e1/`, `REPOS_DIR`.

## Questions à traiter

Chaque réponse est chiffrée en minutes facturées/mois, à partir des exports. Pas de chiffre, pas de constat.

1. **Pareto** : quels repos, workflows, jobs, events font 80 % des minutes facturées ?
2. **Arrondi** : coût du découpage en petits jobs. Pour chaque reusable workflow, ratio facturé/réel, et ce que coûterait un regroupement de jobs (en mettant en face la perte de parallélisme et de lisibilité). Rappel : un job sauté par `if:` (`skipped`) n'est pas facturé, un job qui démarre pour ne rien faire l'est.
3. **Renovate** : part des minutes déclenchées par des PRs Renovate. Combien de runs par PR (rebases, re-runs) ? Le coût d'une seule release de `github-actions` propagée à tous les appelants.
4. **Triggers** : doublons `push` + `pull_request`, absence de filtres `paths`/`paths-ignore`, `schedule` sur repo privé, workflows qui tournent sur des changements qui ne les concernent pas (doc seule, Renovate sur un fichier sans rapport).
5. **Overhead fixe** par job : setup runner, harden-runner, checkout complet (`fetch-depth: 0` nécessaire ou non), pulls d'images, installs d'outils non cachés. Quelle part d'un job « utile » de 20 s est du setup ?
6. **Concurrency** : les annulations jouent-elles vraiment (`cancel-in-progress`) ? Runs annulés qui ont tout de même été facturés ?
7. **Échecs et re-runs** : minutes perdues en échecs flaky et en `run_attempt > 1`.
8. **Visibilité** : repos privés qui pourraient être publics (aucun secret dans l'historique, rien de sensible). Les minutes y deviennent gratuites. Ne recommande jamais sans le signaler à E2.2 dans le constat (`contraintes_touchees`, impact sécurité à évaluer) : c'est un arbitrage, pas une optimisation gratuite.
9. **Stockage** : caches et artifacts, rétention, proximité de la limite du plan Free.

## Sorties dans `OUT/e2-1/`

- `findings.yaml` (format du brief, préfixes `COST` et `PERF`).
- `modele-cout.md` : tableau « mesure actuelle → après reco X → après X+Y… », cumulatif, avec hypothèses explicites. Distinguer gain **certain** (job supprimé) et gain **estimé** (cache hit attendu).

## Hors périmètre

Ne pas trancher l'architecture cible (E2.3) : si une optimisation de coût dépend d'un changement d'architecture, écris le constat et cite-le comme dépendance.
