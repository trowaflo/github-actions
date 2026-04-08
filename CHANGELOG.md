# Changelog

## [4.1.1](https://github.com/trowaflo/github-actions/compare/v4.1.0...v4.1.1) (2026-04-08)


### Bug Fixes

* **helm-pr-cleanup:** add get.helm.sh to harden-runner defaults ([#40](https://github.com/trowaflo/github-actions/issues/40)) ([a9544bf](https://github.com/trowaflo/github-actions/commit/a9544bf03d45a231a46562260638b43033a3eaae))

## [4.1.0](https://github.com/trowaflo/github-actions/compare/v4.0.0...v4.1.0) (2026-04-08)


### Features

* merge harden_runner endpoints + test workflows (helm, docker) + yq checksum fix ([#38](https://github.com/trowaflo/github-actions/issues/38)) ([510e1af](https://github.com/trowaflo/github-actions/commit/510e1af91940d9e3a9aaa4b44ca0c9072fa61772))

## [4.0.0](https://github.com/trowaflo/github-actions/compare/v3.1.0...v4.0.0) (2026-04-07)


### ⚠ BREAKING CHANGES

* **helm:** split helm.yml into helm-ci, helm-release, helm-pr-cleanup ([#35](https://github.com/trowaflo/github-actions/issues/35))

### Code Refactoring

* **helm:** split helm.yml into helm-ci, helm-release, helm-pr-cleanup ([#35](https://github.com/trowaflo/github-actions/issues/35)) ([cd356b2](https://github.com/trowaflo/github-actions/commit/cd356b251c9164c99ac3278e4a94e9c156a97522))

## [3.1.0](https://github.com/trowaflo/github-actions/compare/v3.0.0...v3.1.0) (2026-04-06)


### Features

* **quality:** skip SARIF upload on private repos ([#33](https://github.com/trowaflo/github-actions/issues/33)) ([1127812](https://github.com/trowaflo/github-actions/commit/112781274cfbd85caf264bdf50b20501ad11f92c))

## [3.0.0](https://github.com/trowaflo/github-actions/compare/v2.0.0...v3.0.0) (2026-04-06)


### ⚠ BREAKING CHANGES

* **github-actions:** Update actions/setup-node action (actions/setup-node v6.3.0) ([#25](https://github.com/trowaflo/github-actions/issues/25))

### Features

* add json-lint job and validate-renovate reusable workflow ([#18](https://github.com/trowaflo/github-actions/issues/18)) ([7a6d266](https://github.com/trowaflo/github-actions/commit/7a6d266189f57b20d02fe58648717b785055976b))
* SARIF upload pour checkov, trivy, actionlint, kics + badges README ([#21](https://github.com/trowaflo/github-actions/issues/21)) ([89183bc](https://github.com/trowaflo/github-actions/commit/89183bc58b300175e44cb55b1edea7a7de4fc48e))


### Bug Fixes

* add default endpoints to release.yml ([#30](https://github.com/trowaflo/github-actions/issues/30)) ([fba3f66](https://github.com/trowaflo/github-actions/commit/fba3f66ab2fa1cac298095705544a7d71ed7be7f))
* address all 26 deep review findings ([#26](https://github.com/trowaflo/github-actions/issues/26)) ([834934b](https://github.com/trowaflo/github-actions/commit/834934b3386d34fc05737e0f631430255177680b))
* correct actions/setup-node SHA (v4.5.0 n'existe pas) ([#23](https://github.com/trowaflo/github-actions/issues/23)) ([362ed2a](https://github.com/trowaflo/github-actions/commit/362ed2af3c0ed0506aef310081350a97e2b4db7f))


### Continuous Integration

* **github-actions:** Update actions/setup-node action (actions/setup-node v6.3.0) ([#25](https://github.com/trowaflo/github-actions/issues/25)) ([684d46c](https://github.com/trowaflo/github-actions/commit/684d46ce959268ad6a628ad8434069d2ecb159fb))

## [2.0.0](https://github.com/trowaflo/github-actions/compare/v1.0.0...v2.0.0) (2026-04-06)


### ⚠ BREAKING CHANGES

* **github-actions:** BREAKING CHANGE GitHub Actions (major) ([#13](https://github.com/trowaflo/github-actions/issues/13))

### Bug Fixes

* actionlint checksums filename and ci.yml permissions ([#14](https://github.com/trowaflo/github-actions/issues/14)) ([81abcf0](https://github.com/trowaflo/github-actions/commit/81abcf045e35a43075c547d404bf2ef663e7815f))
* disable MD024 for release-please CHANGELOG ([#17](https://github.com/trowaflo/github-actions/issues/17)) ([bb0a484](https://github.com/trowaflo/github-actions/commit/bb0a4842f2824966f699fd15b480216cb7179e4e))
* resolve pre-existing CI lint failures ([#16](https://github.com/trowaflo/github-actions/issues/16)) ([a795758](https://github.com/trowaflo/github-actions/commit/a795758c78c7bc3f265299a02f6d5104bda2de32))


### Continuous Integration

* **github-actions:** BREAKING CHANGE GitHub Actions (major) ([#13](https://github.com/trowaflo/github-actions/issues/13)) ([b3d7d7e](https://github.com/trowaflo/github-actions/commit/b3d7d7e40a9522a6d2e8b0acd35c14867758e466))

## 1.0.0 (2026-04-05)


### Features

* ajouter upload coverage Codecov ([#3](https://github.com/trowaflo/github-actions/issues/3)) ([70a08a7](https://github.com/trowaflo/github-actions/commit/70a08a732791ce4af219f4edf4cabb92f96900e9))
* centralise reusable workflows — quality, ha, helm, docker, release ([#5](https://github.com/trowaflo/github-actions/issues/5)) ([88b7c8a](https://github.com/trowaflo/github-actions/commit/88b7c8ab5b5e252c61c5c7b41e0e95c34a547ab5))
* reusable workflows ha-integration et lint-markdown ([#1](https://github.com/trowaflo/github-actions/issues/1)) ([1875152](https://github.com/trowaflo/github-actions/commit/18751529444219542fdbe79842e829e68529b95f))


### Bug Fixes

* add write permissions for release-please workflow ([#9](https://github.com/trowaflo/github-actions/issues/9)) ([fec18f0](https://github.com/trowaflo/github-actions/commit/fec18f0aeba0a2082137d19c8007fd47f7e73184))
