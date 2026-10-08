#!/usr/bin/env bash
# The state bucket has to exist before `terraform init` can use it (chicken and egg),
# so it is created once, outside Terraform, with versioning so old states can be recovered.
set -euo pipefail
BUCKET="${1:-ratnesh-tfstate-s19}"
REGION="${AWS_DEFAULT_REGION:-ap-south-1}"
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" --query Location --output text
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "state bucket $BUCKET ready (versioning enabled, public access blocked)"
