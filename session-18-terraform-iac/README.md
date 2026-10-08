# Session 18 — Terraform & Infrastructure as Code

**Name:** Ratnesh Vaibhav  ·  **Roll No:** 24bcs10413

| Task | Folder | Content |
|---|---|---|
| 1 — Terraform S3 demo | [`terraform-s3-demo/`](terraform-s3-demo/) | `init → fmt → validate → plan → apply → show → output → destroy` for a private, versioned, encrypted S3 bucket with lifecycle rule and object; plus drift detection |
| 2 — AWS services research | [`aws-services/`](aws-services/) | one README per service, each ending with a hands-on run |

```text
aws-services/
├── 01-iam/README.md            users, groups, roles, policies, permissions, least privilege, best practices  (+ group/user/policy/role hands-on)
├── 02-ec2/README.md            AMI, instance types, key pairs, security groups, EBS, IPs, lifecycle         (+ launch/stop/start/terminate)
├── 03-s3/README.md             buckets, objects, storage classes, versioning, lifecycle, encryption, policies (+ versions, delete markers, TLS policy)
├── 04-vpc/README.md            CIDR, subnets, route tables, IGW, NAT, SG vs NACL, public vs private          (+ VPC with public/private subnets)
└── 05-dynamodb-rds/README.md   DynamoDB keys/items/attributes, RDS engines, backups, Multi-AZ, replicas   (+ table/query, DB/snapshot/replica)
```

## How AWS was used without an AWS account on this laptop

No AWS credentials are configured on my machine, and I did not want to create billable
resources for coursework. All `terraform` and `aws` commands therefore ran against
**Moto** ([`utility/aws-emulator/`](../utility/aws-emulator/)), an open-source local
emulator of the AWS APIs (S3, EC2/VPC, IAM, STS, EKS, DynamoDB, RDS):

```bash
utility/aws-emulator/start.sh            # docker run motoserver/moto (pinned digest) on localhost:4566
source utility/aws-emulator/env.sh       # AWS_ENDPOINT_URL + Moto's dummy "test" keys
```

The requests, responses, IDs and ARNs in the screenshots are real API traffic, but nothing is
running or billed (account `123456789012` is Moto's fixed test account). The Terraform code
is unchanged for real AWS: delete the `aws_endpoint` line from `terraform.tfvars`. Where the
emulator behaves differently from AWS (S3 tags on `CreateBucket`, default encryption, the IAM
policy simulator), the README says so next to the screenshot.

Every screenshot is rendered from a transcript in
[`utility/transcripts/session-18/`](../utility/transcripts/session-18/).

## Deliverables checklist

| Deliverable | Where |
|---|---|
| `terraform-s3-demo/` with main, variables, outputs, provider, tfvars, README | [`terraform-s3-demo/`](terraform-s3-demo/) |
| init / fmt / validate / plan / apply / show / output / destroy | [`terraform-s3-demo/README.md`](terraform-s3-demo/README.md) §1–7 |
| `aws-services/01-iam … 05-dynamodb-rds/README.md` | [`aws-services/`](aws-services/) |
