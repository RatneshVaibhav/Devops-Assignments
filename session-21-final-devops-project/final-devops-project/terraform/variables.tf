variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "owner" {
  type = string
}

variable "name" {
  description = "Prefix for every resource."
  type        = string
  default     = "shelfshare"
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "azs" {
  description = "Availability-zone suffixes to spread the subnets over."
  type        = list(string)
  default     = ["a", "b"]
}

variable "cluster_version" {
  description = "Kubernetes version of the EKS control plane."
  type        = string
  default     = "1.34"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_scaling" {
  type = object({ min = number, desired = number, max = number })
  default = {
    min     = 1
    desired = 2
    max     = 3
  }
}

variable "api_allowed_cidrs" {
  description = "Who may reach the public EKS API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "aws_endpoint" {
  description = "Custom AWS API endpoint (local emulator). null = real AWS."
  type        = string
  default     = null
}
