variable "aws_region" {
  description = "AWS region for the bucket."
  type        = string
  default     = "ap-south-1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket names must be 3-63 characters of lowercase letters, digits, dots and hyphens."
  }
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Person responsible for the resources."
  type        = string
}

variable "noncurrent_version_days" {
  description = "Days to keep old object versions before they expire."
  type        = number
  default     = 30
}

variable "aws_endpoint" {
  description = "Custom AWS API endpoint (local emulator). null = real AWS."
  type        = string
  default     = null
}
