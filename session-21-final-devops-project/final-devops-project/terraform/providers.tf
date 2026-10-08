provider "aws" {
  region = var.aws_region

  # local AWS emulator switch (utility/aws-emulator); null = real AWS
  skip_credentials_validation = var.aws_endpoint != null
  skip_requesting_account_id  = var.aws_endpoint != null
  skip_metadata_api_check     = var.aws_endpoint != null

  endpoints {
    ec2 = var.aws_endpoint
    eks = var.aws_endpoint
    iam = var.aws_endpoint
    sts = var.aws_endpoint
  }

  default_tags {
    tags = {
      Project   = "shelfshare"
      Session   = "21"
      ManagedBy = "Terraform"
      Owner     = var.owner
    }
  }
}
