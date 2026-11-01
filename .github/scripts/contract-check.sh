#!/usr/bin/env bash
# Compares the contract of every reusable workflow (on.workflow_call and the union of
# job permissions) between the working tree and the last release tag, and fails when
# a breaking change is not announced by a `!` in the pull request title.
# The rules are written in docs/contrat.md.
#
# Usage: PR_TITLE="feat!: ..." contract-check.sh [tag]
set -euo pipefail

TAG="${1:-$(git tag --list 'v*' --sort=-v:refname | head -n 1)}"
if [ -z "$TAG" ]; then
  echo "No v* tag found: nothing to compare against."
  exit 0
fi
echo "Contract compared against $TAG"

# jq program: reads {old, new} and prints one line per breaking change.
# shellcheck disable=SC2016
JQ_DIFF='
def level: if . == "write" then 2 elif . == "read" then 1 else 0 end;
def perms:
  [(.permissions // {} | objects), (.jobs // {} | .[] | .permissions // {} | objects)]
  | map(to_entries[]) | group_by(.key)
  | map({key: .[0].key, value: (map(.value | level) | max)}) | from_entries;
def call: .on.workflow_call // {};
(.old | call) as $o | (.new | call) as $n
| ($o.inputs // {}) as $oi | ($n.inputs // {}) as $ni
| ($o.secrets // {}) as $os | ($n.secrets // {}) as $ns
| ($o.outputs // {}) as $oo | ($n.outputs // {}) as $no
| (.old | perms) as $op | (.new | perms) as $np
| (
    ($oi | keys[] | select($ni[.] == null) | "input removed: \(.)"),
    ($oi | keys[] | select($ni[.] != null) as $k
      | (select($oi[$k].type != $ni[$k].type)
          | "input type changed: \($k) (\($oi[$k].type) -> \($ni[$k].type))"),
        (select($oi[$k].default != $ni[$k].default)
          | "input default changed: \($k) (\($oi[$k].default | tojson) -> \($ni[$k].default | tojson))"),
        (select(($ni[$k].required // false) and (($oi[$k].required // false) | not))
          | "input became required: \($k)")),
    ($ni | keys[] | select($oi[.] == null and ($ni[.].required // false)) | "new required input: \(.)"),
    ($os | keys[] | select($ns[.] == null) | "secret removed: \(.)"),
    ($ns | keys[] | select(($ns[.].required // false) and (($os[.].required // false) | not))
      | "secret became required: \(.)"),
    ($oo | keys[] | select($no[.] == null) | "output removed: \(.)"),
    ($np | keys[] | select($np[.] > ($op[.] // 0)) as $k
      | "permission added: \($k): \(["none", "read", "write"][$np[$k]]) (was \(["none", "read", "write"][$op[$k] // 0]))")
  )
'

breaking=()
while IFS= read -r f; do
  old_json=$(git show "$TAG:$f" | yq -o=json '.')
  if [ "$(jq '.on.workflow_call != null' <<<"$old_json")" != "true" ]; then
    continue
  fi
  if [ ! -f "$f" ]; then
    breaking+=("$f: workflow removed")
    continue
  fi
  new_json=$(yq -o=json '.' "$f")
  if [ "$(jq '.on.workflow_call != null' <<<"$new_json")" != "true" ]; then
    breaking+=("$f: workflow_call trigger removed")
    continue
  fi
  while IFS= read -r line; do
    [ -n "$line" ] && breaking+=("$f: $line")
  done < <(jq -rn --argjson old "$old_json" --argjson new "$new_json" "{old: \$old, new: \$new} | $JQ_DIFF")
done < <(git ls-tree --name-only "$TAG" .github/workflows/ | grep -E '\.ya?ml$')

if [ "${#breaking[@]}" -eq 0 ]; then
  echo "No breaking change in the reusable workflow contracts."
  exit 0
fi

echo "Breaking changes since $TAG:"
printf '  - %s\n' "${breaking[@]}"

if grep -Eq '^[a-z]+(\([^)]*\))?!:' <<<"${PR_TITLE:-}"; then
  echo "The title announces them with '!': release-please will cut a major."
  exit 0
fi

echo "::error::Breaking contract change without '!' in the pull request title (e.g. 'feat!: ...'). See docs/contrat.md."
exit 1
