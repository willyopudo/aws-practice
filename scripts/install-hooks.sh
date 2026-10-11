#!/usr/bin/env bash
# Enable this repo's git hooks. Idempotent — safe to re-run.
# Run once after cloning: ./scripts/install-hooks.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks not found — installing via Homebrew..."
  brew install gitleaks
fi

chmod +x "$root/.githooks/"*
git config core.hooksPath .githooks

# Seed the local pattern file. It is gitignored, so a fresh clone will not have
# one — without it the private-pattern check silently does nothing.
if [[ ! -f "$root/.secrets-patterns.local" ]]; then
  cp "$root/.secrets-patterns.local.example" "$root/.secrets-patterns.local"
  echo "! created .secrets-patterns.local from the example — add your real"
  echo "  usernames / account ids to it (the file is gitignored)."
fi

echo "✓ hooks enabled   (core.hooksPath = $(git config --get core.hooksPath))"
echo "✓ gitleaks        $(gitleaks version)"
echo
echo "  Staged changes are now scanned for secrets on every commit."
echo "  Full-history scan:  gitleaks git --config .gitleaks.toml ."
