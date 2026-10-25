# claude-code.yml

Claude Code + Claude Code Review — répond aux mentions `@claude` et à la commande `/review`.

## Usage côté consumer

```yaml
# .github/workflows/claude.yml (dans le repo consumer)
name: Claude

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened]
  pull_request_review:
    types: [submitted]

jobs:
  claude:
    # Filtrer sur l'auteur du contenu lu par le modèle, pas sur github.actor.
    if: >-
      contains(fromJSON('["OWNER", "MEMBER", "COLLABORATOR"]'),
        github.event.comment.author_association ||
        github.event.review.author_association ||
        github.event.issue.author_association)
    uses: trowaflo/github-actions/.github/workflows/claude-code.yml@<sha> # vX.Y.Z
    secrets:
      claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Pas de déclencheur `issues: assigned` : assigner une issue écrite par un tiers fait lire son texte au modèle alors que l'acteur est le propriétaire. Un filtre sur `github.actor` laisse passer ce cas ; un filtre sur `author_association` de l'auteur du contenu le bloque.

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — extra endpoints merged with defaults |

## Secrets

| Secret | Requis | Description |
| --- | --- | --- |
| `claude_code_oauth_token` | Oui | Token OAuth Claude Code |

## Comportement

### Job `claude` — déclenché par `@claude`

S'exécute quand :

- un commentaire d'issue contient `@claude`
- un commentaire de PR contient `@claude`
- une review de PR contient `@claude`
- une issue ouverte contient `@claude` dans le titre ou le corps

Claude lit les instructions dans le commentaire et les exécute.

### Job `claude-review` — déclenché par `/review`

S'exécute quand un commentaire de PR (event `issue_comment`) contient `/review` et que son auteur est `OWNER`, `MEMBER` ou `COLLABORATOR`. Cette garde vit dans le workflow réutilisable : un caller sans filtre d'auteur n'ouvre pas pour autant la review à tous. Claude analyse la PR et poste une review structurée.

> **Auto-trigger désactivé** : le déclenchement automatique sur chaque PR (sans `/review`) est commenté dans le workflow — à réactiver quand les coûts ne sont plus un problème.

## Notes

### Sécurité — repos publics

**Ne pas activer sans restriction.** N'importe qui peut poster `@claude` ou `/review` et déclencher des appels API coûteux.

**Recommandation** : filtrer sur `author_association` (`OWNER`, `MEMBER`, `COLLABORATOR`) de l'auteur du commentaire, de la review ou de l'issue, comme dans l'exemple ci-dessus. `github.actor == github.repository_owner` ne suffit pas : l'acteur n'est pas forcément l'auteur du texte que le modèle lit.

### `additional_permissions: actions: read`

Permet à Claude de lire les résultats de CI sur les PRs pour donner du contexte dans ses réponses.

### Auto-trigger review

Le déclenchement automatique sur chaque PR est conservé en commentaire dans le workflow. Décommenter le bloc `on: pull_request:` et le job correspondant quand tu souhaites l'activer.
