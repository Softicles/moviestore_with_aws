# IAM Module Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}