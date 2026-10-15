#!/usr/bin/env bash
# Stop: while a spec run is active, don't let the agent stop with a failing or
# un-run quality gate unless the iteration limit is reached.
# Loop-safe: if the agent was already blocked at this iteration count and ran no
# new gate since, it is allowed to stop (it has nothing new to try).
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/agent-common.sh
source "$root/scripts/lib/agent-common.sh"

[[ -f "$AGENT_ACTIVE" ]] || exit 0
n="$(read_int "$AGENT_DIR/iterations")"
max="$(active_get max_iterations)"; max="${max:-5}"
last="$(cat "$AGENT_DIR/last-gate" 2>/dev/null || echo NONE)"

[[ "$last" == PASS ]] && exit 0
(( n >= max )) && exit 0
[[ "$(cat "$AGENT_DIR/stop-blocked-at" 2>/dev/null)" == "$n" ]] && exit 0
echo "$n" >"$AGENT_DIR/stop-blocked-at"

if [[ "$last" == NONE ]]; then
  reason="Spec run active but the quality gate has not run. Run scripts/quality-gate.sh."
else
  reason="Quality gate is FAIL (iteration $n/$max). Fix what it reports and re-run scripts/quality-gate.sh, or say why you're stuck."
fi
jq -n --arg r "$reason" '{decision: "block", reason: $r}'
