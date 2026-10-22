#!/usr/bin/env bash
# Usage: ./sync.sh [--dryrun] [--delete] <bucket[/prefix]> <path> [path...]
#   Each <path> is a file or a directory.
#   directory → its contents are synced to s3://bucket/prefix/
#   file      → only that file is synced (parent dir + --exclude "*" --include <name>)
#   --dryrun  show what would be transferred, change nothing
#   --delete  also remove objects under the destination that are not in a synced directory
#             (directories only; ignored for files so one file can't wipe the prefix)
source "$(dirname "$0")/_common.sh"

usage() { die "Usage: $0 [--dryrun] [--delete] <bucket[/prefix]> <path> [path...]"; }

flags=()
delete=false
while [[ $# -gt 0 && "$1" == --* ]]; do
  case "$1" in
    --dryrun) flags+=(--dryrun) ;;
    --delete) delete=true ;;
    *) usage ;;
  esac
  shift
done

[[ $# -ge 2 ]] || usage
dest="${1#s3://}"
dest="${dest%/}"
shift

# Validate everything before touching S3.
for p in "$@"; do
  [[ -e "$p" ]] || die "Not found: $p"
done

guard_account

for p in "$@"; do
  if [[ -d "$p" ]]; then
    args=(${flags[@]+"${flags[@]}"})
    $delete && args+=(--delete)
    run aws s3 sync "$p" "s3://$dest/" ${args[@]+"${args[@]}"}
  else
    run aws s3 sync "$(dirname "$p")" "s3://$dest/" \
      --exclude "*" --include "$(basename "$p")" ${flags[@]+"${flags[@]}"}
  fi
done
echo "✓ Synced $# path(s) → s3://$dest/"
