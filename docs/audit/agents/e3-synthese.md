# E3 — Synthèse

Modèle : Opus 5.5, effort high.

## Mission

Transformer quatre listes de constats en trois livrables actionnables par une personne seule.

## Entrées

`brief-commun.md`, `OUT/e1/`, `OUT/e2-*/`. Accès en lecture aux repos et à `DATA/e0/` pour vérifier un point, pas pour refaire l'audit.

## Travail

1. **Dédup et fusion** : un même défaut vu par deux auditeurs devient un seul constat avec toutes les preuves. Garder les liens entre axes : un constat sécurité qui coûte des minutes, un constat de coût qui dépend de l'architecture.
2. **Arbitrages** : quand deux recommandations s'opposent (regrouper des jobs pour l'arrondi vs isoler les permissions par job ; rendre un repo public pour les minutes vs exposition), poser l'arbitrage explicitement et trancher, avec la raison.
3. **Priorisation** : score impact × effort. Impact = sévérité sécurité, ou minutes/mois économisées, ou temps de réaction supply chain gagné. Quick wins (effort S, impact moyen ou plus) en tête.
4. **Plan** : vagues ordonnées. Chaque étape = une PR (ou un lot de PRs) **testable en preview avant merge**, avec critère de succès mesurable et retour arrière.
5. **ADR** : reprendre `OUT/e2-3/options.md`, l'enrichir des constats coût, sécurité, gouvernance, et trancher.

## Sorties dans `OUT/`

### `rapport.md`

1. Résumé exécutif, 10 lignes max : état, 3 risques majeurs, consommation actuelle et projetée.
2. Chiffres clés : minutes/mois (mesurées), part Renovate, part de l'arrondi, nombre d'actions externes, part pinnée transitivement, maturité sécurité par domaine.
3. Top 10 des constats.
4. Constats par axe, au format du brief.
5. Arbitrages tranchés.
6. Points disputés (si E4 et E3 restent en désaccord).
7. Hors périmètre et limites de l'audit (ce qui n'a pas pu être mesuré).

### `plan.md`

Vagues, chaque étape : constats couverts, changement, repos touchés, test en preview, critère de succès, gain attendu, effort, dépendances.

### `adr-architecture-cible.md`

Format ADR : contexte, options, critères, décision, conséquences (positives et négatives), conditions de remise en cause, plan de migration résumé (renvoi vers `plan.md`).
