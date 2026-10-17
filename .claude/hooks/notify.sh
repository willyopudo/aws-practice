#!/usr/bin/env bash
# macOS banner, plus a phone push via ntfy.sh when NTFY_TOPIC is set.
# Message from $1, else from a hook's JSON on stdin (.message).
msg="${1:-}"
[[ -z "$msg" && ! -t 0 ]] && msg="$(jq -r '.message // empty' 2>/dev/null)"
msg="${msg:-Claude Code needs your attention}"
msg="${msg//\"/\'}"
osascript -e "display notification \"$msg\" with title \"aws-practice agent\" sound name \"Glass\"" 2>/dev/null || true
if [[ -n "${NTFY_TOPIC:-}" ]]; then
  curl -fsS -m 5 -H "Title: aws-practice agent" -H "Tags: robot" \
    -d "$msg" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true
fi
