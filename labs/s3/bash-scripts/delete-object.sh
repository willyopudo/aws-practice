#!/usr/bin/env bash
# Usage: ./delete-object.sh <bucket-name> <key> [version-id]
#   On a versioned bucket, omitting version-id adds a delete marker instead of removing data.
source "$(dirname "$0")/_common.sh"

[[ $# -ge 2 && $# -le 3 ]] || die "Usage: $0 <bucket-name> <key> [version-id]"
bucket="$1"
key="$2"
version_id="${3:-}"

guard_account

args=(--bucket "$bucket" --key "$key")
[[ -n "$version_id" ]] && args+=(--version-id "$version_id")

run aws s3api delete-object "${args[@]}"
echo "✓ Deleted s3://$bucket/$key${version_id:+ (version $version_id)}"
