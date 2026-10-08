# The bucket itself
resource "aws_s3_bucket" "demo" {
  bucket        = var.bucket_name
  force_destroy = true # lets `terraform destroy` remove a bucket that still holds objects

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# Keep every version of every object (undo accidental overwrites/deletes)
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt objects at rest with S3-managed keys
resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# The bucket is private: block every form of public access
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Old versions expire so versioning does not grow storage forever
resource "aws_s3_bucket_lifecycle_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.demo]
}

# One object, to show that Terraform can manage bucket contents too
resource "aws_s3_object" "readme" {
  bucket       = aws_s3_bucket.demo.id
  key          = "docs/README.txt"
  content      = "Bucket ${var.bucket_name} is managed by Terraform (owner: ${var.owner}).\n"
  content_type = "text/plain"
}
