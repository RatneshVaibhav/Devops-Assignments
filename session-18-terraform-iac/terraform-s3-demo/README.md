# Terraform S3 Demo

An AWS S3 bucket built entirely from code: private, versioned, encrypted, with a lifecycle
rule and one managed object.

```text
terraform-s3-demo/
├── provider.tf         terraform{} block (Terraform >= 1.6, hashicorp/aws ~> 6.0) + provider "aws" with default_tags
├── variables.tf        aws_region, bucket_name (validated), environment, owner, noncurrent_version_days, aws_endpoint
├── terraform.tfvars    values for this run
├── main.tf             bucket + versioning + encryption + public-access block + lifecycle + one object
├── outputs.tf          bucket_name, bucket_arn, bucket_region, versioning_status, readme_object
├── .terraform.lock.hcl provider version lock (committed on purpose)
└── README.md
```

## Architecture

```text
 terraform.tfvars ─► variables.tf ─► main.tf ─────────────────────────────► outputs.tf
                                       │
          provider.tf (aws, ap-south-1)│
                                       ▼
                         aws_s3_bucket.demo  "ratnesh-devops-s18-demo"
                           ├── aws_s3_bucket_versioning              Enabled
                           ├── aws_s3_bucket_server_side_encryption  AES256 (SSE-S3)
                           ├── aws_s3_bucket_public_access_block     all four blocks on
                           ├── aws_s3_bucket_lifecycle_configuration noncurrent versions expire after 30 days
                           └── aws_s3_object.readme                  docs/README.txt
```

Since AWS provider v4, bucket settings are **separate resources** that reference the bucket
(`bucket = aws_s3_bucket.demo.id`). Those references are what Terraform uses to order the
creates (bucket first) and the destroys (bucket last). The lifecycle rule also has an explicit
`depends_on` on versioning, because a noncurrent-version rule only makes sense once versioning
is on.

## Where it ran: a local AWS emulator

There are no AWS credentials on my laptop, so the AWS API was provided by **Moto**
([`utility/aws-emulator/`](../../utility/aws-emulator/)), an open-source emulator that
implements the real S3/EC2/IAM/... APIs. The configuration is still real-AWS ready:

```hcl
# terraform.tfvars
aws_endpoint = "http://localhost:4566"   # delete this line to deploy to real AWS
```

With `aws_endpoint = null`, the `endpoints {}` values are null and the four `skip_*` /
`s3_use_path_style` flags are `false`, so the provider behaves exactly as with no emulator.
On real AWS, the prerequisites are `aws configure` (or SSO) and a globally unique
`bucket_name`.

---

## 1. `terraform init`, `fmt`, `validate`

![emulator started, dummy test credentials, sts get-caller-identity returns account 123456789012, files listed, terraform init installs hashicorp/aws v6.68.0 and writes the lock file, fmt check passes, validate succeeds](../../utility/screenshots/session-18/01_init_fmt_validate.png)

- `init` downloaded **hashicorp/aws v6.68.0** (signed by HashiCorp) and wrote
  `.terraform.lock.hcl`. The lock file is committed so every machine gets the same provider
  version.
- `fmt -diff` printed nothing (already canonical) and `fmt -check` exits 0, the same check a CI
  job would run.
- `validate` checks syntax and types without calling AWS.

## 2. `terraform plan`

![plan showing the six resources with all their attributes and Plan: 6 to add, 0 to change, 0 to destroy](../../utility/screenshots/session-18/02_plan_1.png)
![plan continued: encryption, versioning and object resources](../../utility/screenshots/session-18/02_plan_2.png)
![end of plan with the five outputs listed as known after apply and the saved plan file message](../../utility/screenshots/session-18/02_plan_3.png)

`Plan: 6 to add, 0 to change, 0 to destroy`. Attributes like `arn` show
`(known after apply)` because AWS assigns them.

## 3. `terraform apply` (with the interactive approval)

![terraform apply shows the plan, asks Do you want to perform these actions, Enter a value: yes](../../utility/screenshots/session-18/03_apply_1.png)
![resources being created in dependency order](../../utility/screenshots/session-18/03_apply_2.png)
![Apply complete! Resources: 6 added, with the bucket name, ARN, region ap-south-1, readme object URI and versioning Enabled outputs](../../utility/screenshots/session-18/03_apply_3.png)

The approval was typed into a real terminal (pseudo-terminal recorded by
[`ptyrun.py`](../../utility/tools/ptyrun.py)), so `Enter a value: yes` is exactly what was on
screen. The bucket was created first, then the five dependants. The lifecycle configuration
took ~55 s: S3 lifecycle changes are eventually consistent, so the provider keeps re-reading
the configuration until it consistently matches what was written.

## 4. `terraform output`, `terraform state`, `terraform show`

![terraform output, output -raw bucket_arn, output -json through jq, state list with six resources, terraform show of the bucket resource](../../utility/screenshots/session-18/04_show_output_state.png)

## 5. Verifying with the AWS CLI (outside Terraform)

![aws s3 ls shows the bucket, the uploaded object and its content, versioning Enabled, AES256 encryption rule, all four public access blocks true, the lifecycle rule and the tag table](../../utility/screenshots/session-18/05_verify_with_aws_cli.png)

## 6. Drift detection

The first check of `get-bucket-tagging` returned `NoSuchTagSet`, although the config sets tags.
Investigation with `TF_LOG=DEBUG` showed that provider v6 sends tags **inside the
`CreateBucket` call** (a 2025 S3 feature that Moto does not implement yet), while later
updates use `PutBucketTagging`. The next `terraform plan` reported the missing tags as drift,
and an apply wrote them. To show drift handling cleanly, I then reproduced it on purpose:

![tags deleted with the AWS CLI outside Terraform, terraform plan detects 1 to change and shows the tags to add, apply modifies the bucket, a new plan finds no differences with exit code 0](../../utility/screenshots/session-18/06_drift_detection.png)

`terraform plan` compares the state with the real infrastructure, so a manual change is caught
and reverted to what the code says. `-detailed-exitcode` (0 = no changes, 2 = changes) is
how a scheduled CI job can alert on drift.

## 7. `terraform plan -destroy` and `terraform destroy`

![plan -destroy lists six resources to destroy](../../utility/screenshots/session-18/07_plan_destroy.png)
![destroy asks for confirmation, Enter a value: yes](../../utility/screenshots/session-18/08_destroy_1.png)
![resources destroyed in reverse dependency order](../../utility/screenshots/session-18/08_destroy_2.png)
![Destroy complete! Resources: 6 destroyed; aws s3 ls shows 0 buckets and the state is empty](../../utility/screenshots/session-18/08_destroy_3.png)

The dependants went first and the bucket last, the reverse of the create order. Because of
`force_destroy = true` the bucket could be removed even though it still held a versioned
object. Afterwards there are 0 buckets and the state is empty.

## Complete command list

```bash
../../utility/aws-emulator/start.sh && source ../../utility/aws-emulator/env.sh
aws sts get-caller-identity
terraform init
terraform fmt -recursive -diff && terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply                     # answer: yes
terraform output && terraform output -json
terraform state list && terraform show
aws s3 ls && aws s3api get-bucket-versioning --bucket ratnesh-devops-s18-demo
terraform plan -destroy
terraform destroy                   # answer: yes
```
