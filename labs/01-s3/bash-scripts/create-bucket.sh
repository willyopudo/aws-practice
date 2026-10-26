#!/usr/bin/env bash
# Usage: ./create-bucket.sh <bucket-name>
source "$(dirname "$0")/_common.sh"

[[ $# -eq 1 ]] || die "Usage: $0 <bucket-name>"
bucket="$1"

guard_account
region="$(resolve_region)"

# us-east-1 rejects an explicit LocationConstraint.
if [[ "$region" == "us-east-1" ]]; then
  run aws s3api create-bucket --bucket "$bucket" --region "$region"
else
  run aws s3api create-bucket --bucket "$bucket" --region "$region" \
    --create-bucket-configuration "LocationConstraint=$region"
fi

run aws s3api put-bucket-tagging --bucket "$bucket" \
  --tagging "TagSet=[{Key=Project,Value=aws-practice},{Key=Lab,Value=$LAB_NAME}]"

echo "✓ Created s3://$bucket in $region"
