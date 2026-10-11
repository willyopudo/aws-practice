#!/usr/bin/env bash
# Confirm which AWS account you are about to touch.
# Exits non-zero if it is NOT the practice account — safe to use as a guard:
#   ./scripts/whoami.sh && terraform apply
set -uo pipefail

PRACTICE_ACCOUNT="395931907369"
PROFILE="${AWS_PROFILE:-default}"

id_json=$(aws sts get-caller-identity --profile "$PROFILE" --output json 2>&1) || {
  echo "✗ Could not get caller identity for profile '$PROFILE'" >&2
  echo "$id_json" >&2
  exit 1
}

account=$(echo "$id_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["Account"])')
arn=$(echo "$id_json"     | python3 -c 'import json,sys; print(json.load(sys.stdin)["Arn"])')
region=$(aws configure get region --profile "$PROFILE" 2>/dev/null || echo "unset")

echo "profile : $PROFILE"
echo "account : $account"
echo "arn     : $arn"
echo "region  : $region"

if [[ "$account" != "$PRACTICE_ACCOUNT" ]]; then
  echo
  echo "✗ STOP. This is NOT the practice account ($PRACTICE_ACCOUNT)." >&2
  echo "  You are pointed at a One Acre Fund org account. Do not create resources here." >&2
  exit 2
fi

echo
echo "✓ Practice account confirmed."
