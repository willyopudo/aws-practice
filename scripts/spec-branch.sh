#!/usr/bin/env bash
# Put a spec run on its own fresh branch, cut from an up-to-date origin/main.
#   scripts/spec-branch.sh specs/001-foo.md   # start: clean tree check, new branch, mark active
#   scripts/spec-branch.sh --done             # finish: back to main, clear the active marker
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-common.sh"
cd "$AGENT_ROOT"

if [[ "${1:-}" == "--done" ]]; then
  [[ -n "$(git status --porcelain)" ]] && die "Working tree not clean; commit or stash before finishing."
  git switch --quiet main
  rm -f "$AGENT_ACTIVE" "$AGENT_DIR"/{iterations,last-gate,stop-blocked-at}
  echo "✓ Spec run closed; back on main."
  exit 0
fi

spec="${1:?usage: scripts/spec-branch.sh <specs/NNN-name.md> | --done}"
[[ -f "$spec" ]] || die "No such spec: $spec"
id="$(spec_get "$spec" id)"
[[ -n "$id" ]] || die "$spec has no 'id:' in its frontmatter."

# The spec file itself may be new or edited — it travels to the new branch with the run.
dirty="$(git status --porcelain --untracked-files=all | grep -vF -- "$spec" || true)"
[[ -z "$dirty" ]] || die "Working tree not clean; commit or stash first:"$'\n'"$dirty"

current="$(git branch --show-current)"
if [[ "$current" == spec/* && "$current" != "spec/$id-"* ]]; then
  die "On $current, which belongs to a different spec. Finish it first (scripts/spec-branch.sh --done)."
fi

base=main
if git remote get-url origin >/dev/null 2>&1; then
  git fetch --quiet origin main
  base=origin/main
fi
branch="spec/$id-$(date +%Y%m%d-%H%M%S)"
git switch --quiet -c "$branch" "$base"

mkdir -p "$AGENT_DIR/runs" "$AGENT_DIR/logs"
max="$(spec_get "$spec" max_iterations)"
printf 'spec=%s\nid=%s\nbranch=%s\nmax_iterations=%s\n' "$spec" "$id" "$branch" "${max:-5}" >"$AGENT_ACTIVE"
rm -f "$AGENT_DIR"/{iterations,last-gate,stop-blocked-at}
[[ -f "$AGENT_DIR/runs/$id.md" ]] || echo "# Run log: $id" >"$AGENT_DIR/runs/$id.md"
echo "- $(date '+%F %T') started on $branch (from $base)" >>"$AGENT_DIR/runs/$id.md"

echo "✓ On $branch (from $base). Spec run active: $id"
