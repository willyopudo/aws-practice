#!/usr/bin/env bash
# Usage: ./delete-bucket.sh <bucket-name> [--force]
#   --force  empty the bucket first (all object versions and delete markers)
source "$(dirname "$0")/_common.sh"

[[ $# -ge 1 && $# -le 2 ]] || die "Usage: $0 <bucket-name> [--force]"
bucket="$1"
force="${2:-}"
[[ -z "$force" || "$force" == "--force" ]] || die "Unknown option: $force"

guard_account

if [[ "$force" == "--force" ]]; then
  read -r -p "Permanently delete ALL objects in s3://$bucket? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "Aborted."

  # delete-objects accepts max 1000 keys; 500 versions + 500 markers stays under that.
  while true; do
    payload=$(run aws s3api list-object-versions --bucket "$bucket" --max-items 500 --output json \
      --query '{Objects: [Versions[].{Key:Key,VersionId:VersionId}, DeleteMarkers[].{Key:Key,VersionId:VersionId}][], Quiet: `true`}')
    count=$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)["Objects"] or []))' <<<"$payload")
    [[ "$count" -eq 0 ]] && break
    run aws s3api delete-objects --bucket "$bucket" --delete "$payload" >/dev/null
    echo "  deleted $count object version(s)"
  done
fi

run aws s3api delete-bucket --bucket "$bucket"
echo "✓ Deleted s3://$bucket"
