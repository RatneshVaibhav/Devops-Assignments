terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Local AWS emulator support. With aws_endpoint = null (the default) every
  # line below is a no-op and the provider talks to real AWS with the
  # credentials from `aws configure`.
  skip_credentials_validation = var.aws_endpoint != null
  skip_requesting_account_id  = var.aws_endpoint != null
  skip_metadata_api_check     = var.aws_endpoint != null
  s3_use_path_style           = var.aws_endpoint != null

  endpoints {
    s3  = var.aws_endpoint
    sts = var.aws_endpoint
  }

  default_tags {
    tags = {
      Project   = "devops-assignments"
      Session   = "18"
      ManagedBy = "Terraform"
      Owner     = var.owner
    }
  }
}
