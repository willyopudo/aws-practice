#!/usr/bin/env bash
# One-time: install the CLIs the quality gates and the agent workflow need.
# kcov and sonar-scanner run in Docker and are pulled on first use.
set -euo pipefail

brew install gh shellcheck bats-core jq
# tflint is not in homebrew-core; `make lint` falls back to its Docker image.

gh auth status >/dev/null 2>&1 || gh auth login

echo "✓ Dev tools installed."
echo "  SonarCloud: export SONAR_TOKEN=... (from sonarcloud.io → My Account → Security)"
echo "  and add it as the SONAR_TOKEN secret in the GitHub repo."
