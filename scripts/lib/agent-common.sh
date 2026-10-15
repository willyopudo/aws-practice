#!/usr/bin/env bash
# Shared helpers for the spec-driven agent workflow — sourced, not run directly.
# State lives in .agent/ (gitignored):
#   .agent/active        key=value of the spec run in progress (spec, id, branch, max_iterations)
#   .agent/iterations    number of quality-gate runs in this spec run
#   .agent/last-gate     PASS | FAIL from the most recent quality-gate run
#   .agent/logs/         full tool output per gate stage
#   .agent/runs/<id>.md  the agent's plan + progress notes for that spec

AGENT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENT_DIR="$AGENT_ROOT/.agent"
AGENT_ACTIVE="$AGENT_DIR/active"

die() { echo "✗ $*" >&2; exit 1; }

# spec_get <spec-file> <key> — read a flat `key: value` from the YAML frontmatter.
spec_get() {
  awk -v k="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---"  { exit }
    NR > 1 {
      split($0, kv, ":")
      if (kv[1] == k) { sub(/^[^:]*:[ \t]*/, ""); sub(/[ \t]+#.*$/, ""); print; exit }
    }' "$1"
}

# active_get <key> — read a value from .agent/active (empty if no run is active).
active_get() {
  [[ -f "$AGENT_ACTIVE" ]] || return 0
  awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$AGENT_ACTIVE"
}

read_int() { local v; v="$(cat "$1" 2>/dev/null || true)"; echo "${v:-0}"; }
