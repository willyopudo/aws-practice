#!/usr/bin/env bash
# PreToolUse(Bash): hard guards that prefix-based permission rules can't express.
#  - commits/pushes only from the active spec's branch, never main
#  - no hook bypass, no force push, no push to main
#  - no AWS calls against corporate org profiles (see CLAUDE.md)
# Exit 2 blocks the call and shows stderr to Claude.
input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
block() { echo "BLOCKED by .claude/hooks/bash-guard.sh: $*" >&2; exit 2; }

if grep -qE -- '\baws\b[^|;&#]*--profile[ =]+(acc-|shared-infra)|(^|[;&| ])AWS_PROFILE=(acc-|shared-infra)' <<<"$cmd"; then
  block "org account profiles are off-limits from this repo."
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
active="$root/.agent/active"

if [[ -f "$active" ]] && grep -qE '\bterraform\b.*\b(apply|destroy|import)\b' <<<"$cmd"; then
  block "spec runs never touch real infrastructure; use 'terraform test' with mock_provider."
fi

grep -qE '\bgit\b.*\b(commit|push)\b' <<<"$cmd" || exit 0

grep -qE -- '--no-verify|(^|\s)-n(\s|$)' <<<"$cmd" && block "never bypass the pre-commit hook."
push="$(grep -oE 'git push[^;&|]*' <<<"$cmd")"
if [[ -n "$push" ]]; then
  grep -qE -- '--force|\s-f(\s|$)|\s\+' <<<"$push" && block "no force pushes."
  grep -qE '\b(main|master)\b' <<<"$push" && block "never push to main; open a PR."
fi

# Branch rules apply to this project only, judged in the repo the command runs in.
target="$(git -C "${cwd:-$root}" rev-parse --show-toplevel 2>/dev/null)"
[[ "$target" == "$root" ]] || exit 0
branch="$(git -C "$root" branch --show-current)"
[[ "$branch" == main || "$branch" == master ]] && block "on $branch — every spec runs on its own branch (scripts/spec-branch.sh <spec>)."

if [[ -f "$active" ]]; then
  want="$(awk -F= '$1 == "branch" { print $2 }' "$active")"
  [[ "$branch" == "$want" ]] || block "on $branch but the active spec run is on $want."
fi
exit 0
