#!/usr/bin/env bash
# Shared helpers — sourced by the other scripts, not run directly.
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$COMMON_DIR/../../.." && pwd)"
# shellcheck disable=SC2034  # read by the scripts that source this file
LAB_NAME="s3"

die() { echo "✗ $*" >&2; exit 1; }

# Print the exact command (shell-quoted, to stderr) then run it.
run() {
  printf '+' >&2
  printf ' %q' "$@" >&2
  printf '\n' >&2
  "$@"
}

# Abort unless the active profile points at the practice account.
guard_account() {
  "$REPO_ROOT/scripts/whoami.sh" >/dev/null || die "Account guard failed. Run ./scripts/whoami.sh for details."
}

resolve_region() {
  local r="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
  [[ -z "$r" ]] && r="$(aws configure get region 2>/dev/null || true)"
  echo "${r:-eu-north-1}"
}
