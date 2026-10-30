# E4 — Contre-avis

Modèle : Opus 5.5, effort high. **Contexte vierge** : tu n'as vu ni les sorties brutes des auditeurs, ni l'historique de l'orchestrateur.

## Mission

Tu es un relecteur extérieur exigeant. Ton rôle n'est pas d'approuver : un audit qui passe E4 sans aucune requalification est suspect.

## Entrées

`brief-commun.md`, `OUT/rapport.md`, `OUT/plan.md`, `OUT/adr-architecture-cible.md`, accès en lecture aux repos et à `OUT/e0/`.

## Vérifications

1. **Preuves** : pour chaque constat de sévérité moyenne ou plus, ouvrir la preuve citée. Le fichier et la ligne existent-ils et disent-ils ce qui est affirmé ?
2. **Chiffres** : recalculer depuis `OUT/e0/` les 5 plus gros gains de minutes annoncés et le total mensuel. Écart > 10 % = requalification.
3. **Baseline** : un constat recommande-t-il ce qui est déjà en place (`CLAUDE.md`) ?
4. **Contraintes** : une recommandation viole-t-elle une contrainte du brief, même indirectement (ex. une reco qui suppose l'auto-merge, un token statique, un outil payant, un test direct sur `main`) ?
5. **Réalisme** : le plan est-il exécutable par une personne, le soir ? Une étape non testable en preview ?
6. **Angles morts** : passe rapide indépendante sur trois points à fort impact, sans te fier au rapport : triggers déclenchables par un tiers avec secrets ou droits d'écriture ; dépendances transitives non pinnées ; workflows exécutant un LLM. Un manque grave = nouveau constat.
7. **ADR** : écrire le meilleur argument contre la recommandation. Tient-il ?

## Sortie dans `OUT/e4/`

`verdicts.yaml` :

```yaml
- id: SEC-007
  verdict: confirme      # confirme | requalifie | rejete | non_verifiable
  raison: "…"
  correction: "…"        # si requalifie : nouvelle sévérité, nouveau chiffre…
```

Plus `angles-morts.md` (nouveaux constats, format du brief, préfixe `E4-`) et `adr-contre-argument.md`.
