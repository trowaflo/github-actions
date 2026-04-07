# docker-bake.hcl — Test fixture for test-docker.yml
# Builds a minimal hello-world image from tests/docker/Dockerfile.
# Used only by the CI test workflow in this repo (not a consumer fixture).

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "REPO" {
  default = "trowaflo/github-actions"
}

group "default" {
  targets = ["hello-world"]
}

target "hello-world" {
  context    = "tests/docker"
  dockerfile = "Dockerfile"
  tags       = ["${REGISTRY}/${REPO}/hello-world:test"]
  platforms  = ["linux/amd64"]
}
