provider "aws" {
  region = var.aws_region

  # Only active when aws_endpoint is set (local AWS emulator); null = real AWS.
  skip_credentials_validation = var.aws_endpoint != null
  skip_requesting_account_id  = var.aws_endpoint != null
  skip_metadata_api_check     = var.aws_endpoint != null
  s3_use_path_style           = var.aws_endpoint != null

  endpoints {
    ec2 = var.aws_endpoint
    iam = var.aws_endpoint
    s3  = var.aws_endpoint
    sts = var.aws_endpoint
  }

  default_tags {
    tags = {
      Project   = var.project
      Session   = "19"
      ManagedBy = "Terraform"
      Owner     = var.owner
    }
  }
}

# second provider: generates the random suffix that keeps the bucket name globally unique
provider "random" {}
