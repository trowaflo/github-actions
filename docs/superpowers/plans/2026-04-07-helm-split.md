# Helm Workflows Split — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the monolithic `helm.yml` reusable workflow into three focused files: `helm-ci.yml`, `helm-release.yml`, `helm-pr-cleanup.yml`.

**Architecture:** Each new file handles one trigger context (PR / push-main / PR-closed). Jobs within `helm-ci.yml` are chained with explicit `needs:` dependencies to enforce the `lint → test → bump → docs → docs-check` order, solving the bump→stale-docs race condition. Job bodies (steps) are copied verbatim from `helm.yml`.

**Tech Stack:** GitHub Actions YAML, reusable workflows (`workflow_call`), yamllint, actionlint.

---

## File map

| Action | Path |
| --- | --- |
| Create | `.github/workflows/helm-ci.yml` |
| Create | `.github/workflows/helm-release.yml` |
| Create | `.github/workflows/helm-pr-cleanup.yml` |
| Delete | `.github/workflows/helm.yml` |
| Modify | `docs/helm.md` |
| Modify | `CLAUDE.md` |

---

## Key dependency logic (helm-ci.yml)

GitHub Actions skips a job by default when any `needs:` dependency was skipped. To allow optional jobs (controlled by `enable_*` flags) to chain correctly, every dependent job must explicitly handle the `skipped` result:

```yaml
needs: [helm-bump]
if: >-
  ${{ inputs.enable_docs &&
      (needs.helm-bump.result == 'success' || needs.helm-bump.result == 'skipped') }}
```

This pattern repeats for every job that depends on an optional predecessor.

---

## Task 1 — Create `helm-ci.yml`

**Files:**

- Create: `.github/workflows/helm-ci.yml`

- [ ] **Step 1: Create the file**

```yaml
name: Helm CI

# Reusable workflow — Helm Charts CI (pull_request)
# Usage: uses: trowaflo/github-actions/.github/workflows/helm-ci.yml@<sha>
#
# Job order: lint + unittest → bump → docs → docs-check
#                                  └──────────────→ pr-charts

on:
  workflow_call:
    inputs:
      enable_harden_runner:
        description: "Runtime security via StepSecurity harden-runner"
        type: boolean
        default: true
      harden_runner_egress_policy:
        description: "Harden-runner egress policy: audit (observe) or block (enforce allowlist)"
        type: string
        default: "block"
      harden_runner_allowed_endpoints:
        description: "Allowed endpoints when egress-policy is block (space-separated)"
        type: string
        # setup-helm, helm-docs (GitHub releases), npm (semver), yq
        default: >-
          github.com:443
          api.github.com:443
          release-assets.githubusercontent.com:443
          registry.npmjs.org:443
          objects.githubusercontent.com:443
      enable_lint:
        description: "Lint charts with chart-testing (ct lint)"
        type: boolean
        default: false
      enable_unittest:
        description: "Helm unit tests with helm-unittest (matrix per chart)"
        type: boolean
        default: false
      enable_bump:
        description: "Auto-bump chart versions on PR using conventional commits (major/minor/patch)"
        type: boolean
        default: false
      enable_docs:
        description: "Generate and commit documentation with helm-docs (after bump)"
        type: boolean
        default: false
      enable_docs_check:
        description: "Validate documentation is up-to-date (dry-run, fails if outdated)"
        type: boolean
        default: false
      enable_pr_charts:
        description: "Package modified charts on PR and publish to pr-charts branch"
        type: boolean
        default: false
      charts_dir:
        description: "Root directory for Helm charts"
        type: string
        default: "charts"
      bump_skip_actors:
        description: "Comma-separated actors to skip for version bumping (e.g., 'renovate[bot]')"
        type: string
        default: "renovate[bot]"

permissions: {}

jobs:
  # ─── Lint ────────────────────────────────────────────────────────────────────

  helm-lint:
    if: ${{ inputs.enable_lint }}
    name: Helm Lint
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Harden Runner
        if: ${{ inputs.enable_harden_runner }}
        uses: step-security/harden-runner@fe104658747b27e96e4f7e80cd0a94068e53901d # v2.16.1
        with:
          egress-policy: ${{ inputs.harden_runner_egress_policy }}
          allowed-endpoints: ${{ inputs.harden_runner_allowed_endpoints }}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          fetch-depth: 0
      - uses: azure/setup-helm@1a275c3b69536ee54be43f2070a358922e12c8d4 # v4.3.1
      - uses: actions/setup-python@a309ff8b426b58ec0e2a45f0f869d46889d02405 # v6.2.0
        with:
          python-version: "3.x"
      - uses: helm/chart-testing-action@6ec842c01de15ebb84c8627d2744a0c2f2755c9f # v2.8.0
      - name: List changed charts
        id: list-changed
        env:
          CHARTS_DIR: ${{ inputs.charts_dir }}
        run: |
          changed=$(ct list-changed --target-branch "${{ github.event.repository.default_branch }}" --chart-dirs "$CHARTS_DIR")
          if [ -n "$changed" ]; then
            echo "changed=true" >> "$GITHUB_OUTPUT"
          fi
      - name: Run ct lint
        if: steps.list-changed.outputs.changed == 'true'
        env:
          CHARTS_DIR: ${{ inputs.charts_dir }}
        run: ct lint --target-branch "${{ github.event.repository.default_branch }}" --chart-dirs "$CHARTS_DIR"

  # ─── Unit Tests ──────────────────────────────────────────────────────────────

  helm-unittest-matrix:
    if: ${{ inputs.enable_unittest }}
    name: Detect Test Charts
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
      has_charts: ${{ steps.set-matrix.outputs.has_charts }}
    steps:
      - name: Harden Runner
        if: ${{ inputs.enable_harden_runner }}
        uses: step-security/harden-runner@fe104658747b27e96e4f7e80cd0a94068e53901d # v2.16.1
        with:
          egress-policy: ${{ inputs.harden_runner_egress_policy }}
          allowed-endpoints: ${{ inputs.harden_runner_allowed_endpoints }}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
      - name: Generate chart matrix
        id: set-matrix
        env:
          CHARTS_DIR: ${{ inputs.charts_dir }}
        run: |
          charts_json=$(find "$CHARTS_DIR" -type d -name tests -exec dirname {} \; | sort | jq -R -s -c 'split("\n")[:-1]')
          echo "matrix={\"chart\": $charts_json}" >> "$GITHUB_OUTPUT"
          if [ "$charts_json" != "[]" ]; then
            echo "has_charts=true" >> "$GITHUB_OUTPUT"
          else
            echo "has_charts=false" >> "$GITHUB_OUTPUT"
          fi
          echo "Detected charts: $charts_json"

  helm-unittest:
    if: ${{ inputs.enable_unittest && needs.helm-unittest-matrix.outputs.has_charts == 'true' }}
    needs: helm-unittest-matrix
    name: "Test: ${{ matrix.chart }}"
    runs-on: ubuntu-latest
    permissions:
      contents: read
      checks: write
    strategy:
      fail-fast: false
      max-parallel: 5
      matrix: ${{ fromJson(needs.helm-unittest-matrix.outputs.matrix) }}
    steps:
      - name: Harden Runner
        if: ${{ inputs.enable_harden_runner }}
        uses: step-security/harden-runner@fe104658747b27e96e4f7e80cd0a94068e53901d # v2.16.1
        with:
          egress-policy: ${{ inputs.harden_runner_egress_policy }}
          allowed-endpoints: ${{ inputs.harden_runner_allowed_endpoints }}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
      - uses: azure/setup-helm@1a275c3b69536ee54be43f2070a358922e12c8d4 # v4.3.1
      - name: Cache Helm plugins
        uses: actions/cache@cdf6c1fa76f9f475f3d7449005a359c84ca0f306 # v5.0.3
        with:
          path: ~/.local/share/helm/plugins
          key: helm-unittest-${{ runner.os }}
      - name: Cache Helm dependencies
        uses: actions/cache@cdf6c1fa76f9f475f3d7449005a359c84ca0f306 # v5.0.3
        with:
          path: |
            ${{ matrix.chart }}/charts
            ${{ matrix.chart }}/Chart.lock
          key: helm-deps-${{ matrix.chart }}-${{ hashFiles(format('{0}/Chart.yaml', matrix.chart)) }}
          restore-keys: |
            helm-deps-${{ matrix.chart }}-
      - name: Install helm-unittest plugin
        # renovate: datasource=github-releases depName=helm-unittest/helm-unittest
        run: helm plugin list | grep -q unittest || helm plugin install https://github.com/helm-unittest/helm-unittest.git --version v1.0.3 --verify=false
      - name: Build Helm dependencies
        run: helm dependency update "${{ matrix.chart }}"
      - name: Run Helm unit tests
        run: |
          chart_name=$(basename "${{ matrix.chart }}")
          helm unittest \
            --output-type JUnit \
            --output-file "test-results-${chart_name}.xml" \
            "${{ matrix.chart }}"
      - name: Publish test results
        if: always()
        uses: EnricoMi/publish-unit-test-result-action@c950f6fb443cb5af20a377fd0dfaa78838901040 # v2.23.0
        with:
          files: test-results-*.xml
          check_name: "Test Results - ${{ matrix.chart }}"
          comment_mode: "off"

  # ─── Version Bump ────────────────────────────────────────────────────────────
  # Runs after lint + unittest pass (or are skipped/disabled).

  helm-bump:
    needs: [helm-lint, helm-unittest-matrix, helm-unittest]
    if: >-
      ${{ inputs.enable_bump &&
          github.event_name == 'pull_request' &&
          !contains(inputs.bump_skip_actors, github.actor) &&
          (needs.helm-lint.result == 'success' || needs.helm-lint.result == 'skipped') &&
          (needs.helm-unittest-matrix.result == 'success' || needs.helm-unittest-matrix.result == 'skipped') &&
          (needs.helm-unittest.result == 'success' || needs.helm-unittest.result == 'skipped') }}
    name: Helm Version Bump
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Harden Runner
        if: ${{ inputs.enable_harden_runner }}
        uses: step-security/harden-runner@fe104658747b27e96e4f7e80cd0a94068e53901d # v2.16.1
        with:
          egress-policy: ${{ inputs.harden_runner_egress_policy }}
          allowed-endpoints: ${{ inputs.harden_runner_allowed_endpoints }}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          fetch-depth: 0
          ref: ${{ github.head_ref }}
      - uses: actions/setup-node@53b83947a5a98c8d113130e565377fae1a50d02f # v6.3.0
        with:
          node-version: "24"
      - name: Install semver
        # renovate: datasource=npm depName=semver
        run: npm install --global semver@7.7.4
      - name: Detect changed charts
        id: detect
        env:
          CHARTS_DIR: ${{ inputs.charts_dir }}
          BASE_REF: ${{ github.base_ref }}
        run: |
          git fetch origin "$BASE_REF"
          charts_to_bump=()
          for file in $(git diff --name-only "origin/$BASE_REF..HEAD" | grep "^$CHARTS_DIR/" || true); do
            chart_dir=$(dirname "$file")
            while [ ! -f "$chart_dir/Chart.yaml" ] && [ "$chart_dir" != "." ]; do
              chart_dir=$(dirname "$chart_dir")
            done
            chart="$chart_dir/Chart.yaml"
            # shellcheck disable=SC2076
            if [ -f "$chart" ] && [[ ! " ${charts_to_bump[*]} " =~ " ${chart} " ]]; then
              charts_to_bump+=("$chart")
            fi
          done
          echo "charts=${charts_to_bump[*]}" >> "$GITHUB_OUTPUT"
          echo "Charts to bump: ${charts_to_bump[*]}"
      - name: Bump chart versions (conventional commits)
        if: steps.detect.outputs.charts != ''
        id: bump
        env:
          BASE_REF: ${{ github.base_ref }}
          CHARTS: ${{ steps.detect.outputs.charts }}
        run: |
          bumped_any=false
          for chart in $CHARTS; do
            chart_dir=$(dirname "$chart")

            # Skip if version was already manually bumped
            BASE_VERSION=$(git show "origin/$BASE_REF:$chart" 2>/dev/null | grep '^version:' | awk '{print $2}' || echo "")
            CURRENT_VERSION=$(grep '^version:' "$chart" | awk '{print $2}')
            if [ -n "$BASE_VERSION" ] && [ "$BASE_VERSION" != "$CURRENT_VERSION" ]; then
              echo "Version already bumped for $chart ($BASE_VERSION → $CURRENT_VERSION), skipping."
              continue
            fi

            # Analyze commits affecting this chart for conventional commit type
            COMMITS=$(git log --pretty=%B --no-merges "origin/$BASE_REF..HEAD" -- "$chart_dir")
            bump="none"
            if echo "$COMMITS" | grep -q "BREAKING CHANGE"; then
              bump="major"
            elif echo "$COMMITS" | grep -Eq "^[a-z]+(\([a-z0-9_-]+\))?!:"; then
              bump="major"
            elif echo "$COMMITS" | grep -Eq "^feat[:(]"; then
              bump="minor"
            elif echo "$COMMITS" | grep -Eq "^fix[:(]"; then
              bump="patch"
            fi

            echo "Bump for $chart: $bump"
            if [ "$bump" != "none" ]; then
              new=$(semver -i "$bump" "$CURRENT_VERSION")
              sed -i "s/^version:.*/version: $new/" "$chart"
              echo "Bumped $chart: $CURRENT_VERSION → $new"
              bumped_any=true
            fi
          done
          echo "bumped=$bumped_any" >> "$GITHUB_OUTPUT"
      - name: Commit version bump
        if: steps.bump.outputs.bumped == 'true'
        env:
          CHARTS_DIR: ${{ inputs.charts_dir }}
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          find "$CHARTS_DIR" -name Chart.yaml -exec git add {} +
          git commit -m "ci: bump chart versions [skip ci]"
          git push

  # ─── Documentation ───────────────────────────────────────────────────────────
  # Runs after bump (to capture the new version in the generated README).

  helm-docs:
    needs: [helm-bump]
    if: >-
      ${{ inputs.enable_docs &&
          (needs.helm-bump.result == 'success' || needs.helm-bump.result == 'skipped') }}
    name: Helm Docs
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Harden Runner
        if: ${{ inputs.enable_harden_runner }}
        uses: step-security/harden-runner@fe104658747b27e96e4f7e80cd0a94068e53901d # v2.16.1
        with:
          egress-policy: ${{ inputs.harden_runner_egress_policy }}
          allowed-endpoints: ${{ inputs.harden_runner_allowed_endpoints }}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          ref: ${{ github.head_ref || github.ref_name }}
          token: ${{ secrets.GITHUB_TOKEN }}
      - name: Install helm-docs with checksum verification
        run: |
          set -euo pipefail
          # renovate: datasource=github-releases depName=norwoodj/helm-docs
          VERSION=1.14.2
          ARCHIVE="helm-docs_${VERSION}_Linux_x86_64.tar.gz"
          BASE_URL="https://github.com/norwoodj/helm-docs/releases/download/v${VERSION}"
          cd /tmp
          curl -fsSLO "${BASE_URL}/${ARCHIVE}"
          curl -fsSLO "${BASE_URL}/checksums.txt"
          grep " ${ARCHIVE}$" checksums.txt | sha256sum -c -
          tar -xzf "${ARCHIVE}" helm-docs
          chmod +x helm-docs
      - name: Generate docs
        env:
          CHARTS_DIR: ${{ inputs.charts_dir }}
        run: /tmp/helm-docs --chart-search-root "$CHARTS_DIR"
      - name: Commit updated docs
        env:
          CHARTS_DIR: ${{ inputs.charts_dir }}
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add "$CHARTS_DIR"
          git diff --cached --quiet || (git commit -m "docs: update helm-docs [skip ci]" && git push)

  helm-docs-check:
    needs: [helm-docs]
    if: >-
      ${{ inputs.enable_docs_check &&
          (needs.helm-docs.result == 'success' || needs.helm-docs.result == 'skipped') }}
    name: Helm Docs Check
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Harden Runner
        if: ${{ inputs.enable_harden_runner }}
        uses: step-security/harden-runner@fe104658747b27e96e4f7e80cd0a94068e53901d # v2.16.1
        with:
          egress-policy: ${{ inputs.harden_runner_egress_policy }}
          allowed-endpoints: ${{ inputs.harden_runner_allowed_endpoints }}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          ref: ${{ github.head_ref || github.ref_name }}
      - name: Install helm-docs with checksum verification
        run: |
          set -euo pipefail
          # renovate: datasource=github-releases depName=norwoodj/helm-docs
          VERSION=1.14.2
          ARCHIVE="helm-docs_${VERSION}_Linux_x86_64.tar.gz"
          BASE_URL="https://github.com/norwoodj/helm-docs/releases/download/v${VERSION}"
          cd /tmp
          curl -fsSLO "${BASE_URL}/${ARCHIVE}"
          curl -fsSLO "${BASE_URL}/checksums.txt"
          grep " ${ARCHIVE}$" checksums.txt | sha256sum -c -
          tar -xzf "${ARCHIVE}" helm-docs
          chmod +x helm-docs
      - name: Generate docs
        env:
          CHARTS_DIR: ${{ inputs.charts_dir }}
        run: /tmp/helm-docs --chart-search-root "$CHARTS_DIR"
      - name: Check for changes
        run: |
          git add .
          if git diff --cached --quiet; then
            echo "✅ Documentation is up-to-date."
          else
            echo "❌ Documentation is outdated. Run helm-docs locally to update."
            echo ""
            git diff --cached
            exit 1
          fi

  # ─── PR Charts ───────────────────────────────────────────────────────────────
  # Runs after bump (packages the bumped version).

  helm-pr-charts:
    needs: [helm-bump]
    if: >-
      ${{ inputs.enable_pr_charts &&
          github.event_name == 'pull_request' &&
          (needs.helm-bump.result == 'success' || needs.helm-bump.result == 'skipped') }}
    name: PR Chart Packages
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Harden Runner
        if: ${{ inputs.enable_harden_runner }}
        uses: step-security/harden-runner@fe104658747b27e96e4f7e80cd0a94068e53901d # v2.16.1
        with:
          egress-policy: ${{ inputs.harden_runner_egress_policy }}
          allowed-endpoints: ${{ inputs.harden_runner_allowed_endpoints }}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          fetch-depth: 0
          ref: ${{ github.event.pull_request.head.sha }}
      - uses: azure/setup-helm@1a275c3b69536ee54be43f2070a358922e12c8d4 # v4.3.1
      - name: Configure Git
        run: |
          git config user.name "$GITHUB_ACTOR"
          git config user.email "$GITHUB_ACTOR@users.noreply.github.com"
      - name: Install yq
        run: |
          # renovate: datasource=github-releases depName=mikefarah/yq
          YQ_VERSION="v4.44.2"
          curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
          chmod +x /usr/local/bin/yq
      - name: Detect changed charts
        id: detect
        env:
          CHARTS_DIR: ${{ inputs.charts_dir }}
          BASE_BRANCH: ${{ github.event.pull_request.base.ref }}
        run: |
          git fetch origin "$BASE_BRANCH"
          changed_charts=""
          for file in $(git diff --name-only "origin/$BASE_BRANCH..HEAD" | grep "^$CHARTS_DIR/" || true); do
            chart_dir=$(dirname "$file")
            while [ ! -f "$chart_dir/Chart.yaml" ] && [ "$chart_dir" != "." ]; do
              chart_dir=$(dirname "$chart_dir")
            done
            # shellcheck disable=SC2076
            if [ -f "$chart_dir/Chart.yaml" ] && [[ ! " $changed_charts " =~ " $chart_dir " ]]; then
              changed_charts="$changed_charts $chart_dir"
            fi
          done
          changed_charts=$(echo "$changed_charts" | xargs)
          echo "changed=$changed_charts" >> "$GITHUB_OUTPUT"
          echo "Changed charts: $changed_charts"
      - name: Add Helm repositories
        if: steps.detect.outputs.changed != ''
        run: |
          repos_added=0
          for chart in ${{ steps.detect.outputs.changed }}; do
            chart_file="$chart/Chart.yaml"
            [ -f "$chart_file" ] || continue
            while IFS=$'\t' read -r repo_name repo_url; do
              if [ -n "$repo_name" ] && [ -n "$repo_url" ] && [ "$repo_url" != "null" ]; then
                helm repo add "$repo_name" "$repo_url" 2>/dev/null || true
                repos_added=$((repos_added + 1))
              fi
            done < <(yq '.dependencies[] | select(.repository | test("^https?://")) | [.name, .repository] | @tsv' "$chart_file" 2>/dev/null || true)
          done
          if [ "$repos_added" -gt 0 ]; then helm repo update; fi
      - name: Build chart dependencies
        if: steps.detect.outputs.changed != ''
        run: |
          for chart in ${{ steps.detect.outputs.changed }}; do
            if [ -f "$chart/Chart.yaml" ]; then helm dependency build "$chart"; fi
          done
      - name: Package charts
        if: steps.detect.outputs.changed != ''
        id: package
        run: |
          mkdir -p /tmp/pr-charts /tmp/pr-artifacts
          PR_NUM=${{ github.event.pull_request.number }}
          packaged_charts=""
          for chart in ${{ steps.detect.outputs.changed }}; do
            [ -f "$chart/Chart.yaml" ] || continue
            chart_name=$(yq '.name' "$chart/Chart.yaml")
            chart_version=$(yq '.version' "$chart/Chart.yaml")
            pr_version="${chart_version}-pr${PR_NUM}"

            # PR-versioned package for pr-charts branch
            rm -rf /tmp/chart-copy
            cp -r "$chart" /tmp/chart-copy
            yq ".version = \"${pr_version}\"" -i /tmp/chart-copy/Chart.yaml
            helm package /tmp/chart-copy -d /tmp/pr-charts
            rm -rf /tmp/chart-copy

            # Original version for artifacts
            helm package "$chart" -d /tmp/pr-artifacts
            packaged_charts="$packaged_charts ${chart_name}:${pr_version}"
          done
          echo "packaged=$packaged_charts" >> "$GITHUB_OUTPUT"
      - name: Upload artifacts
        if: steps.package.outputs.packaged != ''
        uses: actions/upload-artifact@bbbca2ddaa5d8feaa63e36b76fdaad77386f024f # v7.0.0
        with:
          name: helm-charts-pr-${{ github.event.pull_request.number }}
          path: /tmp/pr-artifacts/*.tgz
          retention-days: 30
      - name: Publish to pr-charts branch
        if: steps.package.outputs.packaged != ''
        run: |
          PR_NUM=${{ github.event.pull_request.number }}
          git fetch origin pr-charts || true
          if git show-ref --verify --quiet refs/remotes/origin/pr-charts; then
            git checkout pr-charts
          else
            git checkout --orphan pr-charts
            git rm -rf .
            echo "# PR Charts Repository" > README.md
            echo "Charts are versioned with -prN suffix and cleaned up when PRs are merged/closed." >> README.md
            git add README.md
            git commit -m "Initialize pr-charts branch"
          fi
          cp /tmp/pr-charts/*.tgz .
          helm repo index . --url "https://raw.githubusercontent.com/${{ github.repository }}/pr-charts" --merge index.yaml 2>/dev/null || \
          helm repo index . --url "https://raw.githubusercontent.com/${{ github.repository }}/pr-charts"
          git add ./*.tgz index.yaml
          git commit -m "Add PR #${PR_NUM} charts" || echo "No changes to commit"
          git push origin pr-charts
      - name: Comment on PR
        if: steps.package.outputs.packaged != ''
        uses: actions/github-script@ed597411d8f924073f98dfc5c65a23a2325f34cd # v8.0.0
        env:
          PACKAGED: ${{ steps.package.outputs.packaged }}
          REPO_FULL: ${{ github.repository }}
        with:
          script: |
            const packaged = process.env.PACKAGED.trim().split(' ');
            let chartsList = '';
            packaged.forEach(item => {
              if (item) {
                const [name, version] = item.split(':');
                chartsList += `- \`${name}\` version \`${version}\`\n`;
              }
            });
            const repoUrl = `https://raw.githubusercontent.com/${process.env.REPO_FULL}/pr-charts`;
            const body = [
              '## 📦 PR Charts Available for Testing\n',
              chartsList,
              '### Testing with Helm\n',
              '```bash',
              `helm repo add pr-charts ${repoUrl}`,
              'helm repo update',
              'helm install test-release pr-charts/<chart-name> --version <version>',
              '```\n',
              '> 💡 Charts are automatically removed when this PR is merged or closed.'
            ].join('\n');
            const comments = await github.rest.issues.listComments({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
            });
            const existing = comments.data.find(c => c.body.includes('PR Charts Available for Testing'));
            if (existing) {
              await github.rest.issues.updateComment({
                comment_id: existing.id,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: body
              });
            } else {
              await github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: body
              });
            }
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/helm-ci.yml
git commit -m "feat(helm): add helm-ci.yml reusable workflow"
```

---

## Task 2 — Create `helm-release.yml`

**Files:**

- Create: `.github/workflows/helm-release.yml`

- [ ] **Step 1: Create the file**

```yaml
name: Helm Release

# Reusable workflow — Helm Charts Release (push to main)
# Usage: uses: trowaflo/github-actions/.github/workflows/helm-release.yml@<sha>
#
# Docs are NOT regenerated here — they are committed during the PR cycle (helm-ci.yml).

on:
  workflow_call:
    inputs:
      enable_harden_runner:
        description: "Runtime security via StepSecurity harden-runner"
        type: boolean
        default: true
      harden_runner_egress_policy:
        description: "Harden-runner egress policy: audit (observe) or block (enforce allowlist)"
        type: string
        default: "block"
      harden_runner_allowed_endpoints:
        description: "Allowed endpoints when egress-policy is block (space-separated)"
        type: string
        # setup-helm, chart-releaser, yq
        default: >-
          github.com:443
          api.github.com:443
          release-assets.githubusercontent.com:443
          objects.githubusercontent.com:443
      enable_release:
        description: "Release charts via chart-releaser (multi-dir support via release_charts_dirs)"
        type: boolean
        default: false
      charts_dir:
        description: "Root directory for Helm charts"
        type: string
        default: "charts"
      release_charts_dirs:
        description: "Space-separated ordered chart directories to release (max 2, e.g., 'charts/library charts/apps'). If empty, uses charts_dir."
        type: string
        default: ""

permissions: {}

jobs:
  # ─── Release ─────────────────────────────────────────────────────────────────

  helm-release:
    if: ${{ inputs.enable_release }}
    name: Helm Release
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pages: write
    steps:
      - name: Harden Runner
        if: ${{ inputs.enable_harden_runner }}
        uses: step-security/harden-runner@fe104658747b27e96e4f7e80cd0a94068e53901d # v2.16.1
        with:
          egress-policy: ${{ inputs.harden_runner_egress_policy }}
          allowed-endpoints: ${{ inputs.harden_runner_allowed_endpoints }}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          fetch-depth: 0
      - uses: azure/setup-helm@1a275c3b69536ee54be43f2070a358922e12c8d4 # v4.3.1
      - name: Configure Git
        run: |
          git config user.name "$GITHUB_ACTOR"
          git config user.email "$GITHUB_ACTOR@users.noreply.github.com"
      - name: Determine release directories
        id: dirs
        env:
          RELEASE_DIRS: ${{ inputs.release_charts_dirs }}
          CHARTS_DIR: ${{ inputs.charts_dir }}
        run: |
          if [ -n "$RELEASE_DIRS" ]; then
            count=$(echo "$RELEASE_DIRS" | wc -w | tr -d ' ')
            if [ "$count" -gt 2 ]; then
              echo "::warning::release_charts_dirs contains $count directories but only 2 are supported. Extra directories will be ignored."
            fi
            echo "first=$(echo "$RELEASE_DIRS" | awk '{print $1}')" >> "$GITHUB_OUTPUT"
            echo "second=$(echo "$RELEASE_DIRS" | awk '{print $2}')" >> "$GITHUB_OUTPUT"
          else
            echo "first=$CHARTS_DIR" >> "$GITHUB_OUTPUT"
            echo "second=" >> "$GITHUB_OUTPUT"
          fi
      - name: Install yq
        run: |
          # renovate: datasource=github-releases depName=mikefarah/yq
          YQ_VERSION="v4.44.2"
          curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
          chmod +x /usr/local/bin/yq
      - name: Add external Helm repositories
        run: |
          repos_added=0
          for dir in ${{ steps.dirs.outputs.first }} ${{ steps.dirs.outputs.second }}; do
            [ -z "$dir" ] && continue
            for chart_dir in "$dir"/*/; do
              chart_file="$chart_dir/Chart.yaml"
              [ -f "$chart_file" ] || continue
              while IFS=$'\t' read -r repo_name repo_url; do
                if [ -n "$repo_name" ] && [ -n "$repo_url" ] && [ "$repo_url" != "null" ]; then
                  helm repo add "$repo_name" "$repo_url" 2>/dev/null || true
                  repos_added=$((repos_added + 1))
                fi
              done < <(yq '.dependencies[] | select(.repository | test("^https?://")) | [.name, .repository] | @tsv' "$chart_file" 2>/dev/null || true)
            done
          done
          if [ "$repos_added" -gt 0 ]; then helm repo update; fi
      # ── First directory ──
      - name: Build dependencies (first)
        run: |
          for chart in "${{ steps.dirs.outputs.first }}"/*/; do
            if [ -f "$chart/Chart.yaml" ]; then helm dependency build "$chart"; fi
          done
      - name: Release first directory
        uses: helm/chart-releaser-action@cae68fefc6b5f367a0275617c9f83181ba54714f # v1.7.0
        with:
          charts_dir: ${{ steps.dirs.outputs.first }}
          skip_existing: true
        env:
          CR_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          CR_SKIP_EXISTING: true
          CR_GENERATE_RELEASE_NOTES: true
      # ── Second directory (if provided) ──
      - name: Add self as Helm repository
        if: ${{ steps.dirs.outputs.second != '' }}
        run: |
          helm repo add self "https://${{ github.repository_owner }}.github.io/${{ github.event.repository.name }}" || true
          helm repo update
      - name: Build dependencies (second)
        if: ${{ steps.dirs.outputs.second != '' }}
        run: |
          for chart in "${{ steps.dirs.outputs.second }}"/*/; do
            if [ -f "$chart/Chart.yaml" ]; then helm dependency build "$chart"; fi
          done
      - name: Release second directory
        if: ${{ steps.dirs.outputs.second != '' }}
        uses: helm/chart-releaser-action@cae68fefc6b5f367a0275617c9f83181ba54714f # v1.7.0
        with:
          charts_dir: ${{ steps.dirs.outputs.second }}
          skip_existing: true
        env:
          CR_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          CR_SKIP_EXISTING: true
          CR_GENERATE_RELEASE_NOTES: true
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/helm-release.yml
git commit -m "feat(helm): add helm-release.yml reusable workflow"
```

---

## Task 3 — Create `helm-pr-cleanup.yml`

**Files:**

- Create: `.github/workflows/helm-pr-cleanup.yml`

- [ ] **Step 1: Create the file**

```yaml
name: Helm PR Cleanup

# Reusable workflow — Helm PR Charts Cleanup (pull_request closed)
# Usage: uses: trowaflo/github-actions/.github/workflows/helm-pr-cleanup.yml@<sha>
#
# No enable flag — calling this workflow implies cleanup intent.

on:
  workflow_call:
    inputs:
      enable_harden_runner:
        description: "Runtime security via StepSecurity harden-runner"
        type: boolean
        default: true
      harden_runner_egress_policy:
        description: "Harden-runner egress policy: audit (observe) or block (enforce allowlist)"
        type: string
        default: "block"
      harden_runner_allowed_endpoints:
        description: "Allowed endpoints when egress-policy is block (space-separated)"
        type: string
        default: >-
          github.com:443
          api.github.com:443

permissions: {}

jobs:
  # ─── PR Cleanup ──────────────────────────────────────────────────────────────

  helm-pr-cleanup:
    if: ${{ github.event_name == 'pull_request' && github.event.action == 'closed' }}
    name: PR Chart Cleanup
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Harden Runner
        if: ${{ inputs.enable_harden_runner }}
        uses: step-security/harden-runner@fe104658747b27e96e4f7e80cd0a94068e53901d # v2.16.1
        with:
          egress-policy: ${{ inputs.harden_runner_egress_policy }}
          allowed-endpoints: ${{ inputs.harden_runner_allowed_endpoints }}
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          fetch-depth: 0
      - name: Check if pr-charts branch exists
        id: check
        run: |
          if git ls-remote --heads origin pr-charts | grep -q pr-charts; then
            echo "exists=true" >> "$GITHUB_OUTPUT"
          else
            echo "exists=false" >> "$GITHUB_OUTPUT"
          fi
      - uses: azure/setup-helm@1a275c3b69536ee54be43f2070a358922e12c8d4 # v4.3.1
        if: steps.check.outputs.exists == 'true'
      - name: Checkout pr-charts branch
        if: steps.check.outputs.exists == 'true'
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          ref: pr-charts
          fetch-depth: 0
      - name: Configure Git
        if: steps.check.outputs.exists == 'true'
        run: |
          git config user.name "$GITHUB_ACTOR"
          git config user.email "$GITHUB_ACTOR@users.noreply.github.com"
      - name: Remove PR charts and update index
        if: steps.check.outputs.exists == 'true'
        run: |
          PR_NUM=${{ github.event.pull_request.number }}
          rm -f ./*-pr${PR_NUM}.tgz || true
          helm repo index . --url "https://raw.githubusercontent.com/${{ github.repository }}/pr-charts"
          git add -A
          git commit -m "Remove PR #${PR_NUM} charts after merge/close" || echo "No charts to remove"
          git push origin pr-charts || echo "Nothing to push"
      - name: Comment on merged PR
        if: ${{ steps.check.outputs.exists == 'true' && github.event.pull_request.merged == true }}
        uses: actions/github-script@ed597411d8f924073f98dfc5c65a23a2325f34cd # v8.0.0
        with:
          script: |
            await github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '## 🧹 PR Charts Cleaned Up\n\nThe test charts for this PR have been removed from the `pr-charts` branch.'
            });
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/helm-pr-cleanup.yml
git commit -m "feat(helm): add helm-pr-cleanup.yml reusable workflow"
```

---

## Task 4 — Delete `helm.yml`

**Files:**

- Delete: `.github/workflows/helm.yml`

- [ ] **Step 1: Delete the file**

```bash
git rm .github/workflows/helm.yml
git commit -m "refactor(helm): remove monolithic helm.yml — replaced by helm-ci/release/pr-cleanup"
```

---

## Task 5 — Update `docs/helm.md`

**Files:**

- Modify: `docs/helm.md`

- [ ] **Step 1: Replace the file contents**

```markdown
# Helm Workflows

Helm Charts CI/CD — split into three focused reusable workflows.

Tous les jobs sont **désactivés par défaut** (opt-in explicite), sauf `helm-pr-cleanup` qui
s'active dès que le workflow est appelé sur un événement `pull_request closed`.

---

## helm-ci.yml — Pull Request CI

Lint, tests, bump de version, génération de docs, et packaging PR.

**Ordre d'exécution :**

```
lint + unittest → bump → docs → docs-check
                      └──────────────→ pr-charts
```

### Usage

```yaml
jobs:
  helm-ci:
    uses: trowaflo/github-actions/.github/workflows/helm-ci.yml@<sha> # vX.Y.Z
    permissions:
      contents: write
      checks: write
      pull-requests: write
    with:
      enable_lint: true
      enable_unittest: true
      enable_bump: true
      enable_docs: true
      enable_docs_check: true
      enable_pr_charts: true
      charts_dir: "charts"
```

### Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` or `block` |
| `harden_runner_allowed_endpoints` | string | (built-in) | Override replaces defaults |
| `enable_lint` | boolean | `false` | Lint avec `ct lint` |
| `enable_unittest` | boolean | `false` | Unit tests avec helm-unittest |
| `enable_bump` | boolean | `false` | Auto-bump de version des charts modifiés sur PR |
| `enable_docs` | boolean | `false` | Génération doc avec helm-docs (après bump) |
| `enable_docs_check` | boolean | `false` | Valide que les docs sont à jour |
| `enable_pr_charts` | boolean | `false` | Package les charts modifiés et poste un commentaire |
| `charts_dir` | string | `"charts"` | Répertoire racine des charts |
| `bump_skip_actors` | string | `"renovate[bot]"` | Acteurs à ignorer pour le bump |

---

## helm-release.yml — Release

Release des charts via chart-releaser (push sur main).

### Usage

```yaml
jobs:
  helm-release:
    uses: trowaflo/github-actions/.github/workflows/helm-release.yml@<sha> # vX.Y.Z
    permissions:
      contents: write
      pages: write
    with:
      enable_release: true
      charts_dir: "charts"
```

### Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` or `block` |
| `harden_runner_allowed_endpoints` | string | (built-in) | Override replaces defaults |
| `enable_release` | boolean | `false` | Release via chart-releaser |
| `charts_dir` | string | `"charts"` | Répertoire racine des charts |
| `release_charts_dirs` | string | `""` | Répertoires de charts à releaser (max 2, space-separated) |

---

## helm-pr-cleanup.yml — PR Cleanup

Supprime les charts PR de la branche `pr-charts` quand une PR est mergée ou fermée.

Pas de flag — appeler ce workflow implique l'intention de cleanup.

### Usage

```yaml
jobs:
  helm-pr-cleanup:
    uses: trowaflo/github-actions/.github/workflows/helm-pr-cleanup.yml@<sha> # vX.Y.Z
    permissions:
      contents: write
      pull-requests: write
```

### Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `enable_harden_runner` | boolean | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | string | `"block"` | Egress policy: `audit` or `block` |
| `harden_runner_allowed_endpoints` | string | (built-in) | Override replaces defaults |

---

## Secrets

Aucun — utilise `GITHUB_TOKEN` pour toutes les opérations.
```

- [ ] **Step 2: Commit**

```bash
git add docs/helm.md
git commit -m "docs: update helm.md for split workflows"
```

---

## Task 6 — Update `CLAUDE.md`

**Files:**

- Modify: `CLAUDE.md`

- [ ] **Step 1: Find and replace the helm inputs section**

In `CLAUDE.md`, find the section starting with `## helm.yml inputs` and replace it with:

```markdown
## helm-ci.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_lint` | `false` | Lint charts with chart-testing (ct lint) |
| `enable_unittest` | `false` | Helm unit tests with helm-unittest (matrix per chart) |
| `enable_bump` | `false` | Auto-bump chart versions on PR using conventional commits |
| `enable_docs` | `false` | Generate and commit helm-docs (runs after bump) |
| `enable_docs_check` | `false` | Validate documentation is up-to-date (fails if outdated) |
| `enable_pr_charts` | `false` | Package modified charts on PR and publish to pr-charts branch |
| `charts_dir` | `"charts"` | Root directory for Helm charts |
| `bump_skip_actors` | `"renovate[bot]"` | Comma-separated actors to skip for version bumping |

## helm-release.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
| `enable_release` | `false` | Release charts via chart-releaser (multi-dir support via release_charts_dirs) |
| `charts_dir` | `"charts"` | Root directory for Helm charts |
| `release_charts_dirs` | `""` | Space-separated ordered chart directories to release (max 2) |

## helm-pr-cleanup.yml inputs

| Input | Default | Description |
| --- | --- | --- |
| `enable_harden_runner` | `true` | Runtime security via StepSecurity harden-runner |
| `harden_runner_egress_policy` | `"block"` | Egress policy: `audit` (observe) or `block` (enforce allowlist) |
| `harden_runner_allowed_endpoints` | `(built-in)` | Allowed endpoints when block (space-separated) — override replaces defaults |
```

- [ ] **Step 2: Also update the repository structure comment block**

Find `helm.yml` in the structure diagram and replace:

```
  helm.yml             # Helm: release, lint, unittest, docs, docs-check, bump, PR charts, PR cleanup
```

with:

```
  helm-ci.yml          # Helm CI: lint, unittest, bump, docs, docs-check, pr-charts (pull_request)
  helm-release.yml     # Helm Release: chart-releaser (push to main)
  helm-pr-cleanup.yml  # Helm Cleanup: remove pr-charts on PR close
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for split helm workflows"
```

---

## Validation

After all tasks are complete:

- [ ] Open a PR on this repo — CI must pass (`yamllint`, `actionlint`, `sha-check`)
- [ ] Check that no `uses:` in the 3 new files uses tags or branch names (all SHAs already pinned — copied from helm.yml)
