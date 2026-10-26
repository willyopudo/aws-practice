#!/usr/bin/env bash
# Usage: ./list-objects.sh <bucket-name> [prefix]
source "$(dirname "$0")/_common.sh"

[[ $# -ge 1 && $# -le 2 ]] || die "Usage: $0 <bucket-name> [prefix]"
bucket="$1"
prefix="${2:-}"

guard_account

args=(--bucket "$bucket")
[[ -n "$prefix" ]] && args+=(--prefix "$prefix")

run aws s3api list-objects-v2 "${args[@]}" \
  --query 'Contents[].{Key:Key,Size:Size,LastModified:LastModified}' \
  --output table
