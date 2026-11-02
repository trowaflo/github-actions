# lint.yml

Lint et qualité de code. actionlint est **activé par défaut** (opt-out). Les autres linters sont **désactivés par défaut** (opt-in).

Un seul job `Lint`, une étape par linter activé. Une minute est facturée par job démarré et la mise en place d'un job (runner, harden-runner, checkout) coûte environ 13 s : huit jobs de 20 s étaient facturés huit minutes. Chaque étape porte `continue-on-error`, les autres linters tournent donc même si l'un échoue, et la dernière étape (`Fail if a linter failed`) rend le job rouge en nommant les étapes en échec.

## Usage

```yaml
jobs:
  lint:
    uses: trowaflo/github-actions/.github/workflows/lint.yml@<sha> # vX.Y.Z
    permissions:
      contents: read
      security-events: write   # SARIF uploads (actionlint, shellcheck, shfmt), repos publics
    with:
      enable_markdown_lint: true
      enable_yamllint: true
      enable_json_lint: true
      enable_ansible_lint: true   # opt-in pour les repos Ansible
```

## Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | string | `(built-in)` | Allowed endpoints when block (space-separated) — extra endpoints merged with defaults |
| `enable_actionlint` | boolean | `true` | Lint des fichiers workflow GitHub Actions |
| `enable_markdown_lint` | boolean | `false` | Lint Markdown avec markdownlint-cli2 |
| `enable_yamllint` | boolean | `false` | Lint YAML avec yamllint |
| `enable_json_lint` | boolean | `false` | Validation syntaxe JSON et JSON5 |
| `enable_ansible_lint` | boolean | `false` | Lint Ansible avec ansible-lint |
| `enable_shellcheck` | boolean | `false` | shellcheck sur les `*.sh` suivis par git, non bloquant |
| `enable_shfmt` | boolean | `false` | Formatage `shfmt -i 2 -ci` des `*.sh` suivis par git, non bloquant |
| `enable_terraform_validate` | boolean | `false` | `terraform fmt` + `tflint` |

## Permissions requises

Le job appelant accorde exactement ces deux permissions, quels que soient les linters activés. GitHub contrôle l'appelant contre toutes les permissions déclarées par le workflow appelé avant d'évaluer le moindre `if:`.

| Permission | Usage |
| --- | --- |
| `contents: read` | checkout |
| `security-events: write` | upload SARIF (actionlint, shellcheck, shfmt), sur les repos publics seulement |

`pull-requests: write` n'est plus demandé : un appelant qui l'accorde encore peut le retirer.

## Secrets

Aucun — utilise `GITHUB_TOKEN` implicitement.

## Notes

### actionlint

Version gérée via Renovate (`datasource=github-releases depName=rhysd/actionlint`). Les binaires sont vérifiés par checksum SHA-256.

Les résultats sont uploadés au format SARIF — annotations inline sur les PRs.

### json_lint

Valide la syntaxe de tous les fichiers `*.json` (via `json.load`) et `*.json5` (via `json5.load`). Les fichiers dans `.git/` et `node_modules/` sont exclus.

### yamllint

Créer un `.yamllint.yml` à la racine du repo pour surcharger la configuration par défaut.

### Paquets Python épinglés par hash

yamllint, json5 et ansible-lint s'installent chacun dans leur venv avec `pip install --require-hashes --only-binary=:all:`, depuis un fichier de requirements écrit dans le job : un workflow appelé ne voit que le checkout du caller, jamais un fichier de ce dépôt. Chaque paquet, dépendances transitives comprises, porte le hash des wheels que le runner peut choisir (manylinux x86_64, `abi3` ou `py3-none-any`, CPython 3.12 à 3.14).

Renovate bumpe la version via l'annotation `# renovate:` ; les hashes, eux, ne suivent pas et l'installation échoue fermée tant qu'ils ne sont pas régénérés. Pour un paquet seul :

```bash
curl -s https://pypi.org/pypi/<paquet>/<version>/json | jq -r '.urls[]
  | select(.filename | test("py3-none-any|cp31[2-4]-cp31[2-4]-manylinux.*x86_64|cp3[0-9]+-abi3-manylinux.*x86_64|py3-none-manylinux.*x86_64"))
  | "\(.digests.sha256) \(.filename)"'
```

Pour ansible-lint, le jeu transitif change d'une version à l'autre : le régénérer en entier, puis appliquer la commande ci-dessus à chaque ligne.

```bash
echo "ansible-lint==<version>" > in.txt
uv pip compile in.txt --universal --python-version 3.12 --only-binary :all: --no-header --no-annotate
```

Les marqueurs (`; python_full_version < '3.14'`) que rend `--universal` restent sur la ligne du paquet.

### ansible-lint

Installé depuis PyPI par hash, pas par l'action `ansible/ansible-lint` : cette action composite exécute `astral-sh/setup-uv@v7`, un tag que l'épinglage par SHA de l'action englobante ne fige pas.

### shellcheck, shfmt

shellcheck (préinstallé sur le runner ubuntu) et shfmt (binaire officiel vérifié par SHA-256) analysent les `*.sh` suivis par git, en entier.

Ils ne bloquent pas : une trouvaille ne rend pas le job rouge, comme avec les actions reviewdog qu'ils remplacent (`fail_on_error: false`). Seule une erreur d'exécution compte comme échec.

Les trouvailles vont :

- dans le résumé du job, partout ;
- en SARIF dans Security > Code scanning, sur les repos publics seulement. Code scanning n'est pas gratuit en privé.

Plus aucun commentaire de PR : c'est ce qui exigeait `pull-requests: write` de tous les appelants.

shfmt applique `-i 2 -ci` (indentation 2 espaces, `case` indenté). Sa version suit l'annotation Renovate de `SHFMT_VERSION` ; le SHA-256 `SHFMT_SHA256` se met à jour à la main, sinon l'étape échoue fermée :

```bash
gh release view v<version> -R mvdan/sh --json assets --jq '.assets[] | select(.name|endswith("linux_amd64")) | .digest'
```

### harden-runner

[StepSecurity harden-runner](https://github.com/step-security/harden-runner) sécurise le réseau du job. Par défaut, la politique egress est `block`. Les linters partageant un job, l'allowlist intégrée est l'union de ce qu'ils téléchargent :

| Hôte | Pour |
| --- | --- |
| `agent.api.stepsecurity.io` | agent harden-runner |
| `api.github.com` | runtime, upload SARIF, setup-tflint |
| `files.pythonhosted.org`, `pypi.org` | yamllint, json5, ansible-lint |
| `github.com` | checkout, actionlint, shfmt, tflint |
| `raw.githubusercontent.com` | gabarit SARIF d'actionlint |
| `release-assets.githubusercontent.com` | assets de release (cible de redirection) |
| `releases.hashicorp.com` | Terraform |

Un hôte propre au consumer s'ajoute via `harden_runner_allowed_endpoints` ; `audit` sert seulement à découvrir ces hôtes, jamais comme réglage durable.
