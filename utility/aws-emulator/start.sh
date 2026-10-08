#!/usr/bin/env bash
# start.sh - run Moto, an open-source AWS API emulator, on http://localhost:4566.
#
# There are no AWS credentials on this laptop, so sessions 18, 19 and 21 point
# Terraform and the AWS CLI at this emulator. It implements the real AWS APIs
# (S3, EC2/VPC, IAM, STS, EKS, DynamoDB, RDS ...) in memory: resources are
# created, described and destroyed exactly like on AWS, but nothing runs and
# nothing is billed. Stop it with:  docker rm -f aws-emulator
set -euo pipefail
IMAGE="motoserver/moto@sha256:91fd602a21f49cf9eb82fdf474015a3c131d40104c8297ea6a2ca920708ae32c"  # moto 5.2.3.dev0
if [ "$(docker inspect -f '{{.State.Running}}' aws-emulator 2>/dev/null || true)" != "true" ]; then
  docker rm -f aws-emulator >/dev/null 2>&1 || true
  # MOTO_IAM_LOAD_MANAGED_POLICIES: preload AWS-managed policies such as AmazonEKSClusterPolicy
  docker run -d --name aws-emulator -p 127.0.0.1:4566:5000 \
    -e MOTO_IAM_LOAD_MANAGED_POLICIES=true "$IMAGE" >/dev/null
fi
until curl -s -o /dev/null http://localhost:4566/moto-api/; do sleep 1; done
echo "AWS emulator (moto) listening on http://localhost:4566"
