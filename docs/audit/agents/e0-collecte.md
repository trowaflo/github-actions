# E0 — Collecte déterministe

Pas d'agent LLM : l'orchestrateur écrit un script, l'utilisateur le valide, le script produit des exports. Toutes les phases suivantes travaillent sur ces exports.

## Token

Fine-grained PAT **éphémère** (7 jours max, révoqué après l'audit), lecture seule, limité aux repos `trowaflo/*` :

- Repository : `Actions: read`, `Administration: read`, `Contents: read`, `Metadata: read`, `Pull requests: read`, `Secrets: read` (noms uniquement), `Environments: read`.
- Account : `Plan: read` (billing), si l'endpoint l'exige.

C'est la seule exception tolérée à la contrainte 3, bornée dans le temps, et le token ne quitte jamais la machine de l'utilisateur : les agents LLM ne le voient pas.

## Exports attendus

Tout dans `OUT/e0/`. Formats plats (CSV, JSONL) pour être lus par morceaux.

| Fichier | Contenu | Source |
| --- | --- | --- |
| `repos.csv` | Tous les repos non archivés : visibilité, fork, branche par défaut, dernier push | `gh repo list trowaflo --no-archived --json …` |
| `callers.csv` | Pour chaque repo : utilise `trowaflo/github-actions` (oui/non), quels workflows, à quelle ref | Lecture de `.github/workflows/*` via l'API contents, **pas** la code search (elle rate des repos privés) |
| `workflows/<repo>/*.yml` | Copie brute des workflows de chaque repo, plus `action.yml` des actions locales | API contents |
| `runs.jsonl` | Runs des 90 derniers jours : repo, run_id, workflow, event, branche, acteur, conclusion, `run_attempt`, dates | `actions/runs?created=>…` paginé |
| `jobs.jsonl` | Jobs de ces runs : nom, labels runner, started/completed, conclusion, **billed_minutes** calculé | `runs/{id}/jobs` avec `--paginate`, règle de `CLAUDE.md` |
| `billing-by-job.csv` | Agrégat repo × workflow × job : nb d'exécutions, minutes réelles, minutes facturées, ratio, taux d'échec, nb de re-runs | Calcul local sur `jobs.jsonl` |
| `billing-by-event.csv` | Agrégat repo × event × acteur (`renovate[bot]` séparé) | Calcul local |
| `billing-official.json` | Usage officiel du compte, si l'API billing répond | `users/trowaflo/settings/billing/usage` ; en cas d'échec, écrire l'erreur, ne pas inventer |
| `storage.csv` | Par repo : taille et nombre de caches, artifacts, rétention | `actions/caches`, `actions/artifacts` |
| `settings.jsonl` | Par repo : permissions par défaut du `GITHUB_TOKEN`, approbation des PR par Actions, actions autorisées, rulesets, branch protection, environnements, **noms** des secrets | `actions/permissions`, `actions/permissions/workflow`, `rulesets`, `branches/{b}/protection`, `actions/secrets` |
| `renovate-prs.csv` | PRs Renovate des 90 jours : repo, titre, ouverture, merge/fermeture, délai, nb de runs CI déclenchés | `gh pr list --author app/renovate --state all` + jointure `runs.jsonl` |
| `uses-inventory.csv` | Chaque `uses:` : repo, fichier, ligne, cible, ref, type de pin (`sha`, `tag`, `branch`, `docker-digest`, `docker-tag`, `local`), commentaire de version | Parsing YAML des workflows collectés |
| `uses-transitive.csv` | Pour chaque action externe à son SHA : type (`composite`, `docker`, `node`), ses propres `uses:` et leur pin, image Docker et son pin, téléchargements à l'exécution repérables (`curl`, `wget`, scripts d'install) | `action.yml` récupéré au SHA exact, profondeur 2 |
| `scanners/zizmor/<repo>.json` | `zizmor --persona auditor --format json` | Sur chaque repo cloné |
| `scanners/poutine/<repo>.json` | `poutine analyze_local` | Idem |
| `scanners/actionlint/<repo>.txt` | `actionlint` | Idem |
| `scanners/scorecard/<repo>.json` | OpenSSF Scorecard, **repos publics uniquement** | `scorecard --repo=…` |

Versions des outils : épinglées et notées dans `OUT/e0/tools.txt`. Un outil qui échoue : consigner l'erreur, continuer, ne pas « corriger » en sautant le repo silencieusement.

## Contraintes du script

- Idempotent et reprenable : cache par appel API, reprise après rate limit (`X-RateLimit-Remaining`).
- Aucune écriture sur GitHub. Aucun appel hors `api.github.com`, `github.com` et registres des outils.
- Clones shallow dans `REPOS_DIR`, jamais exécutés : aucun script des repos audités n'est lancé.
- Masque toute valeur qui ressemble à un secret dans les exports (les noms de secrets restent).

## Checklist de fin

- [ ] `callers.csv` liste autant de repos que `repos.csv`.
- [ ] Somme de `billing-by-job.csv` sur le dernier mois complet, comparée à `billing-official.json` si disponible ; écart > 10 % documenté dans `OUT/e0/ecarts.md`.
- [ ] Chaque scanner a une sortie (ou une erreur consignée) par repo.
- [ ] Aucun secret en clair : `gitleaks dir OUT/e0` vert.
