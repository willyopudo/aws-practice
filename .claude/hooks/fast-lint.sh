#!/usr/bin/env bash
# PostToolUse(Edit|Write): lint only the file just edited, so mistakes surface
# immediately and cheaply instead of at the next full quality-gate run.
# Exit 2 feeds stderr back to Claude; output is capped to keep context small.
file="$(jq -r '.tool_input.file_path // empty')"
[[ -f "$file" ]] || exit 0

case "$file" in
  *.sh|*.bash|*/.githooks/*|*/tests/helpers/bin/*)
    command -v shellcheck >/dev/null || exit 0
    out="$(cd "$(dirname "$file")" && shellcheck -x -S warning -f gcc "$file" 2>&1)" ;;
  *.tf)
    command -v terraform >/dev/null || exit 0
    terraform fmt "$file" >/dev/null 2>&1  # auto-fix formatting rather than report it
    exit 0 ;;
  *) exit 0 ;;
esac

[[ -z "$out" ]] && exit 0
echo "$out" | head -n 10 >&2
exit 2
