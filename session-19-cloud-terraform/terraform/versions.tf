terraform {
  required_version = ">= 1.10.0" # S3 native state locking (use_lockfile)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  # Remote state in S3. The bucket/key/region come from a backend config file:
  #   terraform init -backend-config=backend-emulator.hcl   (local AWS emulator)
  #   terraform init -backend-config=backend-aws.hcl        (real AWS)
  backend "s3" {}
}
