# E5 — Veille supply chain

À activer après l'audit, si le plan le confirme.

## Objectif

Être prévenu dans la journée quand une action utilisée par un repo `trowaflo/*` est touchée par un advisory ou montre un signe de compromission, avec la liste des repos concernés : le déclencheur du kill-switch défini dans l'ADR.

## Design recommandé : déterministe d'abord, LLM sur alerte

Le croisement inventaire × advisories est mécanique : pas besoin d'un LLM chaque semaine.

1. **Détection** (sans LLM) : workflow planifié dans **ce repo public** (minutes gratuites, `GITHUB_TOKEN` éphémère en lecture, contrainte 3 respectée). Il régénère l'inventaire des `uses:` de ce repo et de leurs dépendances transitives, puis interroge :
   - la GitHub Advisory Database, écosystème `actions` ;
   - OSV pour le même écosystème ;
   - les tags upstream : un tag de version dont le SHA a changé par rapport au commentaire de version épinglé (tag repointé = signal fort de compromission) ;
   - l'état des repos d'actions : archivé, transféré, supprimé.
2. **Alerte** : notification vers un canal privé (ntfy ou issue dans un repo **privé**). Pas d'issue publique ici : elle annoncerait une exposition non corrigée.
3. **Triage** (LLM, à la demande ou déclenché par l'alerte) : Haiku 5.5 effort low lit l'alerte et l'inventaire, écarte les faux positifs évidents (version non utilisée). S'il reste un cas, escalade vers Sonnet 5.5 effort medium : exploitabilité dans notre usage, repos concernés, action recommandée selon le kill-switch de l'ADR.

## Point ouvert

L'inventaire des workflows **locaux** des repos privés n'est pas lisible depuis ce repo public avec le seul `GITHUB_TOKEN`. Options à trancher dans l'ADR : limiter la veille aux actions centralisées ici (incite à tout centraliser), une GitHub App en lecture seule avec tokens d'installation éphémères, ou un workflow léger dans chaque appelant qui publie son inventaire. Aucun PAT longue durée.

## Critères de succès

- Délai advisory → notification : moins de 24 h.
- Zéro faux positif récurrent après deux semaines (sinon, liste d'exclusion versionnée et relue).
- Coût : 0 minute sur le quota privé.
