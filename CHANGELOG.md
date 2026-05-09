# Changelog

## [2.1.0](https://github.com/trowaflo/github-actions/compare/v2.0.0...v2.1.0) (2026-05-09)


### Features

* **release-helm:** add enable_oci_release toggle for GHCR dual-publish on main ([#57](https://github.com/trowaflo/github-actions/issues/57)) ([d47f6a2](https://github.com/trowaflo/github-actions/commit/d47f6a2ac14adf7b45c3952c21e4272d62d92988))

## [2.0.0](https://github.com/trowaflo/github-actions/compare/v1.2.0...v2.0.0) (2026-05-09)


### ⚠ BREAKING CHANGES

* **github-actions:** Update GitHub Actions (major) (DavidAnson/markdownlint-cli2-action v23.0.0, azure/setup-helm v5, azure/setup-helm v5, azure/setup-helm v5, azure/setup-helm v5, azure/setup-helm v5, codecov/codecov-action v6) (major) ([#51](https://github.com/trowaflo/github-actions/issues/51))

### Features

* **ci-helm:** dual-publish PR charts to branch and OCI/GHCR ([#55](https://github.com/trowaflo/github-actions/issues/55)) ([69096df](https://github.com/trowaflo/github-actions/commit/69096df4ba9eb3e23332eb3d5e54acb38df2b825))


### Bug Fixes

* **ci-helm-cleanup:** reconcile orphan PR charts on every run ([#54](https://github.com/trowaflo/github-actions/issues/54)) ([60ccdb3](https://github.com/trowaflo/github-actions/commit/60ccdb3d0518dc9aa922f605ca889dd3c8584aee))
* use github-actions[bot] identity in helm publish workflows ([#52](https://github.com/trowaflo/github-actions/issues/52)) ([33a8b42](https://github.com/trowaflo/github-actions/commit/33a8b42edfe8afa9b2aa7f7d58f9225a8d4ec31a))


### Continuous Integration

* **github-actions:** Update GitHub Actions (major) (DavidAnson/markdownlint-cli2-action v23.0.0, azure/setup-helm v5, azure/setup-helm v5, azure/setup-helm v5, azure/setup-helm v5, azure/setup-helm v5, codecov/codecov-action v6) (major) ([#51](https://github.com/trowaflo/github-actions/issues/51)) ([dabb2d7](https://github.com/trowaflo/github-actions/commit/dabb2d7e5832ca678725214bb32fc56efb82a47b))

## [1.2.0](https://github.com/trowaflo/github-actions/compare/v1.1.0...v1.2.0) (2026-04-13)


### Features

* add shellcheck and shfmt linters to lint.yml via reviewdog ([fec84c5](https://github.com/trowaflo/github-actions/commit/fec84c501f12a10e31d2f1a39067ce476b9408cb))

## [1.1.0](https://github.com/trowaflo/github-actions/compare/v1.0.0...v1.1.0) (2026-04-09)


### Features

* enforce harden runner egress policy across all workflows ([#44](https://github.com/trowaflo/github-actions/issues/44)) ([d15f2fd](https://github.com/trowaflo/github-actions/commit/d15f2fdb601dd0d03a5e3f0c34d2e735f6c67595))

## [1.0.0] — 2026-04-09

Initial release — reusable GitHub Actions workflows for `trowaflo/*` repositories.
