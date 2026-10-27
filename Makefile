# Quality gates. `make check` is what the agent loop and CI both run.
# SonarCloud is not part of `check`: CI runs it on PR / push to main. `make sonar` runs it on demand.
# Run scripts/quality-gate.sh for a compact summary instead of raw output.
SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

COVERAGE_MIN ?= 80
SH_FILES     := $(shell git ls-files --cached --others --exclude-standard '*.sh' '*.bash' '.githooks/*' 'tests/helpers/bin/*')
TF_DIRS      := $(sort $(dir $(shell git ls-files --cached --others --exclude-standard '*.tf')))
BATS_FILES   := $(shell find tests -name '*.bats' 2>/dev/null)

KCOV_IMAGE   := aws-practice-kcov
SONAR_IMAGE  := sonarsource/sonar-scanner-cli:11
# tflint left homebrew-core; use a local install if present, else the official image.
TFLINT       := $(shell command -v tflint || echo docker run --rm -v "$(CURDIR):/data" -w /data ghcr.io/terraform-linters/tflint:v0.59.1)
BRANCH       := $(shell git branch --show-current)

.PHONY: check lint test coverage sonar sonar-local sonar-local-down clean

check: lint test coverage

lint:
	shellcheck -x -S warning $(SH_FILES)
	terraform fmt -check -recursive
	@for d in $(TF_DIRS); do $(TFLINT) --chdir="$$d" || exit 1; done

test:
ifeq ($(BATS_FILES),)
	@echo "no bats tests yet"
else
	bats --recursive tests
endif

# kcov runs inside Docker: it is unreliable on macOS and this matches CI.
coverage:
	@docker image inspect $(KCOV_IMAGE) >/dev/null 2>&1 || docker build -q -t $(KCOV_IMAGE) tests/docker >/dev/null
	rm -rf coverage
ifneq ($(BATS_FILES),)
	docker run --rm -v "$(CURDIR):/src" -w /src $(KCOV_IMAGE) \
	  kcov --include-path=/src/scripts,/src/labs coverage bats --recursive tests >/dev/null
endif
	scripts/coverage-check.sh coverage $(COVERAGE_MIN)

# SONAR_TOKEN comes from the environment only. Never write it to a file.
sonar:
	@[[ -n "$${SONAR_TOKEN:-}" ]] || { echo "SONAR_TOKEN not set"; exit 3; }
	docker run --rm -e SONAR_TOKEN -v "$(CURDIR):/usr/src" $(SONAR_IMAGE) \
	  -Dsonar.qualitygate.wait=true -Dsonar.branch.name=$(BRANCH)

# Local SonarQube Community in Docker; no SonarCloud, no SONAR_TOKEN needed.
sonar-local:
	scripts/sonar-local.sh

sonar-local-down:
	scripts/sonar-local.sh --down

clean:
	rm -rf coverage .scannerwork
