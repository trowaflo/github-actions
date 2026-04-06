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
    types: [opened, assigned]
  pull_request_review:
    types: [submitted]

jobs:
  claude:
    # Restreindre au propriétaire du repo uniquement (repos publics)
    if: github.actor == github.repository_owner
    uses: trowaflo/github-actions/.github/workflows/claude-code.yml@<sha> # vX.Y.Z
    secrets:
      claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### Alternative : autoriser membres et collaborateurs

```yaml
    if: |
      github.event.comment.author_association == 'OWNER' ||
      github.event.comment.author_association == 'MEMBER' ||
      github.event.comment.author_association == 'COLLABORATOR'
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `""` | Allowed endpoints when block (space-separated) |

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
- une issue ouverte/assignée contient `@claude` dans le titre ou le corps

Claude lit les instructions dans le commentaire et les exécute.

### Job `claude-review` — déclenché par `/review`

S'exécute quand un commentaire de PR contient `/review`. Claude analyse la PR et poste une review structurée.

> **Auto-trigger désactivé** : le déclenchement automatique sur chaque PR (sans `/review`) est commenté dans le workflow — à réactiver quand les coûts ne sont plus un problème.

## Notes

### Sécurité — repos publics

**Ne pas activer sans restriction.** N'importe qui peut poster `@claude` ou `/review` et déclencher des appels API coûteux.

**Recommandation** : restreindre au propriétaire du repo via `github.actor == github.repository_owner`. C'est le filtre le plus strict et le plus simple.

Si plusieurs personnes doivent pouvoir déclencher Claude, utiliser `author_association` (`MEMBER`, `COLLABORATOR`).

### `additional_permissions: actions: read`

Permet à Claude de lire les résultats de CI sur les PRs pour donner du contexte dans ses réponses.

### Auto-trigger review

Le déclenchement automatique sur chaque PR est conservé en commentaire dans le workflow. Décommenter le bloc `on: pull_request:` et le job correspondant quand tu souhaites l'activer.
