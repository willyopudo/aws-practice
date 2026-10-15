#!/usr/bin/env bash
# Run a spec headless with hard limits, stopping before commit for your approval.
#   scripts/agent-run.sh specs/001-foo.md
# Limits come from the spec frontmatter (model, max_turns, max_budget_usd).
# Commit / push / PR are permission "ask" rules, which headless mode always denies,
# so this can never ship anything. Approve by resuming the printed session.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-common.sh"
cd "$AGENT_ROOT"

spec="${1:?usage: scripts/agent-run.sh <specs/NNN-name.md>}"
[[ -f "$spec" ]] || die "No such spec: $spec"
command -v claude >/dev/null || die "claude CLI not found"
command -v jq >/dev/null || die "jq not found"

model="$(spec_get "$spec" model)";             model="${model:-sonnet}"
budget="$(spec_get "$spec" max_budget_usd)";   budget="${budget:-3}"
turns="$(spec_get "$spec" max_turns)";         turns="${turns:-60}"

# Branch before the model does anything.
scripts/spec-branch.sh "$spec"

args=(-p "/spec-run $spec" --model "$model" --max-budget-usd "$budget"
      --output-format json --permission-mode acceptEdits)
# --max-turns is hidden from --help in some CLI versions; only pass it if accepted.
if claude -p --max-turns 1 --help >/dev/null 2>&1; then args+=(--max-turns "$turns"); fi

out="$AGENT_DIR/runs/$(spec_get "$spec" id).json"
echo "▶ $spec  model=$model  budget=\$$budget  turns≤$turns"
AGENT_HEADLESS=1 claude "${args[@]}" >"$out" || true

session="$(jq -r '.session_id // empty' "$out")"
cost="$(jq -r '.total_cost_usd // "?"' "$out")"
nturns="$(jq -r '.num_turns // "?"' "$out")"
subtype="$(jq -r '.subtype // "?"' "$out")"

echo
jq -r '.result // empty' "$out"
echo
echo "── run: $subtype · turns $nturns · cost \$$cost · gate $(cat "$AGENT_DIR/last-gate" 2>/dev/null || echo '?')"
"$AGENT_ROOT/.claude/hooks/notify.sh" "Spec run finished ($subtype, \$$cost) — review needed"
[[ -n "$session" ]] && echo "Review and approve:  claude --resume $session"
