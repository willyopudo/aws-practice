#!/usr/bin/env bash
# Find leftover billable resources in the practice account.
# Run this after every lab teardown, and any time the bill looks odd.
#
#   ./scripts/sweep.sh            # scan the default region
#   ./scripts/sweep.sh --all      # scan every enabled region (slower)
set -uo pipefail

PROFILE="${AWS_PROFILE:-default}"
AWS=(aws --profile "$PROFILE" --output text)

if [[ "${1:-}" == "--all" ]]; then
  regions=$("${AWS[@]}" ec2 describe-regions --query 'Regions[].RegionName' 2>/dev/null)
else
  regions=$(aws configure get region --profile "$PROFILE" 2>/dev/null || echo us-east-1)
fi

found=0
report() { # region, label, output
  [[ -z "${3// /}" ]] && return
  echo "  [$1] $2:"
  echo "$3" | sed 's/^/      /'
  found=1
}

echo "Sweeping for billable resources (profile: $PROFILE)"
echo

for r in $regions; do
  R=(aws --profile "$PROFILE" --region "$r" --output text)

  report "$r" "EC2 instances (running)" \
    "$("${R[@]}" ec2 describe-instances \
        --filters Name=instance-state-name,Values=running,pending \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType]' 2>/dev/null)"

  report "$r" "NAT Gateways (~\$32/mo each)" \
    "$("${R[@]}" ec2 describe-nat-gateways \
        --filter Name=state,Values=available,pending \
        --query 'NatGateways[].[NatGatewayId,VpcId]' 2>/dev/null)"

  report "$r" "Load balancers (~\$16/mo each)" \
    "$("${R[@]}" elbv2 describe-load-balancers \
        --query 'LoadBalancers[].[LoadBalancerName,Type]' 2>/dev/null)"

  report "$r" "Unattached Elastic IPs (billed when idle)" \
    "$("${R[@]}" ec2 describe-addresses \
        --query 'Addresses[?AssociationId==`null`].[PublicIp,AllocationId]' 2>/dev/null)"

  report "$r" "RDS instances" \
    "$("${R[@]}" rds describe-db-instances \
        --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass]' 2>/dev/null)"

  report "$r" "EKS clusters (~\$73/mo each)" \
    "$("${R[@]}" eks list-clusters --query 'clusters' 2>/dev/null)"

  report "$r" "EBS volumes (available = detached, still billed)" \
    "$("${R[@]}" ec2 describe-volumes \
        --filters Name=status,Values=available \
        --query 'Volumes[].[VolumeId,Size]' 2>/dev/null)"
done

# S3 is global-ish; list once.
report "global" "S3 buckets" \
  "$("${AWS[@]}" s3api list-buckets --query 'Buckets[].Name' 2>/dev/null)"

echo
if [[ $found -eq 0 ]]; then
  echo "✓ Nothing billable found. Clean."
else
  echo "⚠ Review the above. Anything tagged Project=aws-practice is yours to destroy."
  echo "  Prefer 'terraform destroy' in the owning lab over deleting by hand."
fi
