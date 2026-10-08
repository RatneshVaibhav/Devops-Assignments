variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Name prefix for every resource."
  type        = string
  default     = "s19-campus-web"
}

variable "owner" {
  description = "Owner tag."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnets" {
  description = "Public subnets: availability-zone suffix => CIDR."
  type        = map(string)
  default = {
    a = "10.20.1.0/24"
    b = "10.20.2.0/24"
  }
}

variable "private_subnets" {
  description = "Private subnets: availability-zone suffix => CIDR."
  type        = map(string)
  default = {
    a = "10.20.11.0/24"
  }
}

variable "instance_type" {
  description = "EC2 instance type of the web server."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Use a t3.micro/small/medium for this project."
  }
}

variable "admin_cidr" {
  description = "Only this CIDR may SSH to the web server."
  type        = string
  default     = "203.0.113.10/32"
}

variable "aws_endpoint" {
  description = "Custom AWS API endpoint (local emulator). null = real AWS."
  type        = string
  default     = null
}
