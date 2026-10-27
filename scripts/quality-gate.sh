#!/usr/bin/env bash
# Run every quality gate and print a compact summary instead of raw tool output.
#   scripts/quality-gate.sh         # lint, test, coverage, sonar-local (SonarCloud runs in CI)
#   scripts/quality-gate.sh --sonar # also run SonarCloud locally (needs SONAR_TOKEN)
# sonar-local starts a local SonarQube container if needed; see scripts/sonar-local.sh.
# Full logs: .agent/logs/<stage>.log. Exit 0 only if every non-skipped stage passes.
# While a spec run is active, each run counts as one iteration against its limit.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/agent-common.sh"

EXCERPT_LINES=40
cd "$AGENT_ROOT" || exit 1
mkdir -p "$AGENT_DIR/logs"

sonar=0
[[ "${1:-}" == "--sonar" ]] && sonar=1

spec="$(active_get spec)"
coverage_min=80
if [[ -n "$spec" && -f "$spec" ]]; then
  coverage_min="$(spec_get "$spec" coverage_min)"; coverage_min="${coverage_min:-80}"
  [[ "$(spec_get "$spec" sonar)" == "false" ]] && sonar=0
fi
[[ -z "${SONAR_TOKEN:-}" ]] && sonar=0

summary=()
first_fail=""
for stage in lint test coverage sonar-local sonar; do
  if [[ "$stage" == "sonar" && $sonar -eq 0 ]]; then
    summary+=("sonar: SKIPPED"); continue
  fi
  log="$AGENT_DIR/logs/$stage.log"
  if make --no-print-directory "$stage" COVERAGE_MIN="$coverage_min" >"$log" 2>&1; then
    result="PASS"
  else
    result="FAIL"; [[ -z "$first_fail" ]] && first_fail="$stage"
  fi
  [[ "$stage" == "coverage" ]] && result="$(grep -o '[0-9.]*% (min [0-9.]*)' "$log" | tail -1) $result"
  summary+=("$stage: $result")
  [[ -n "$first_fail" ]] && break  # later stages are noise until this one is fixed
done

status=PASS; [[ -n "$first_fail" ]] && status=FAIL
line="$(IFS='|'; echo "${summary[*]}" | sed 's/|/ | /g')"

if [[ -f "$AGENT_ACTIVE" ]]; then
  n=$(( $(read_int "$AGENT_DIR/iterations") + 1 ))
  echo "$n" >"$AGENT_DIR/iterations"
  echo "$status" >"$AGENT_DIR/last-gate"
  max="$(active_get max_iterations)"
  line="[iteration $n/${max:-?}] $line"
  [[ "$status" == FAIL && -n "$max" && $n -ge $max ]] && line="$line"$'\n'"ITERATION LIMIT REACHED — stop fixing and report what is still failing."
fi

echo "GATE $status: $line"
if [[ -n "$first_fail" ]]; then
  echo "--- first $EXCERPT_LINES relevant lines of .agent/logs/$first_fail.log ---"
  grep -vE '^(make|\+|ok [0-9])|^\s*$' "$AGENT_DIR/logs/$first_fail.log" | head -n "$EXCERPT_LINES"
fi
[[ "$status" == PASS ]]
