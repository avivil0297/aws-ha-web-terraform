#!/usr/bin/env bash
# Destroy everything and verify nothing billable is left
set -euo pipefail
cd "$(dirname "$0")/.."

REGION="${AWS_REGION:-us-east-1}"

terraform destroy

echo
echo "=== Verification (all should be empty) ==="
echo "Terraform state:";  terraform state list | grep -v '^data\.' || echo "  (empty)"
echo "NAT gateways:";     aws ec2 describe-nat-gateways --region "$REGION" --filter Name=state,Values=available,pending --query 'NatGateways[].NatGatewayId' --output text
echo "Elastic IPs:";      aws ec2 describe-addresses --region "$REGION" --query 'Addresses[].PublicIp' --output text
echo "Running instances:"; aws ec2 describe-instances --region "$REGION" --filters Name=instance-state-name,Values=running,pending --query 'Reservations[].Instances[].InstanceId' --output text
echo "Load balancers:";   aws elbv2 describe-load-balancers --region "$REGION" --query 'LoadBalancers[].LoadBalancerName' --output text
