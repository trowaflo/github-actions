# Contrat de version

Le contrat d'un reusable workflow, c'est ce qu'un appelant écrit : son `on.workflow_call` et les permissions qu'il doit accorder. Un changement est **cassant** quand un appelant qui ne change rien peut passer au rouge, en `startup_failure` ou en comportement différent. Il impose un titre de PR en `type!:`, et release-please sort une majeure.

Est cassant :

1. retirer un workflow, ou son déclencheur `workflow_call` ;
2. retirer ou renommer un input, un secret ou un output ;
3. changer le type d'un input, ou rendre requis un input ou un secret ;
4. changer la valeur par défaut d'un input (`enable_*`, egress, `kics_fail_on`, `gitleaks_scan_mode`…) ;
5. ajouter une permission à un job, ou passer une permission de `read` à `write` : l'appelant doit l'accorder, même pour un job opt-in désactivé ;
6. ajouter un hôte qu'un appelant doit déclarer, ou retirer un hôte d'une allowlist intégrée dont un appelant dépend.

N'est pas cassant : ajouter un input optionnel, ajouter un workflow, retirer une permission, changer une description.

Le job `Contract Check` de `ci.yml` (`.github/scripts/contract-check.sh`) compare les points 1 à 5 entre la tête de PR et le dernier tag `v*`, et échoue sans `!` dans le titre. Le point 6 reste à la relecture.
