#!/usr/bin/env bash
# macOS banner. Message from $1, else from a hook's JSON on stdin (.message).
msg="${1:-}"
[[ -z "$msg" && ! -t 0 ]] && msg="$(jq -r '.message // empty' 2>/dev/null)"
msg="${msg:-Claude Code needs your attention}"
msg="${msg//\"/\'}"
osascript -e "display notification \"$msg\" with title \"aws-practice agent\" sound name \"Glass\"" 2>/dev/null || true
