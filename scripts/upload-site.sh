#!/usr/bin/env bash
# Upload site/ to S3 via the bastion (only the bastion role may write to the bucket)
set -euo pipefail
cd "$(dirname "$0")/.."

REGION="${AWS_REGION:-us-east-1}"
BASTION=$(terraform output -raw bastion_public_ip)
BUCKET=$(terraform output -raw site_bucket)

echo "Copying site/ to bastion $BASTION ..."
scp -r site "ubuntu@$BASTION:~/"

echo "Uploading to s3://$BUCKET from the bastion ..."
ssh "ubuntu@$BASTION" "command -v aws >/dev/null || sudo snap install aws-cli --classic
aws s3 sync ~/site s3://$BUCKET --delete --region $REGION
aws s3 ls s3://$BUCKET --region $REGION"

echo "Done. Web servers will pick it up within 60 seconds."
