#!/usr/bin/env bash
# Usage: ./put-object.sh <bucket-name> <file-path> [key]
#   key defaults to the file's basename
source "$(dirname "$0")/_common.sh"

[[ $# -ge 2 && $# -le 3 ]] || die "Usage: $0 <bucket-name> <file-path> [key]"
bucket="$1"
file="$2"
key="${3:-$(basename "$file")}"

[[ -f "$file" ]] || die "File not found: $file"

guard_account

run aws s3api put-object --bucket "$bucket" --key "$key" --body "$file"
echo "✓ Uploaded $file → s3://$bucket/$key"
