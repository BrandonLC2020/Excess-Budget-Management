variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "excess-budget-management"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for web hosting"
  type        = string
  default     = "excess-budget-web-hosting"
}
