# EC2 Module Variables

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "jenkins_security_group_id" {
  description = "Security group ID for Jenkins master"
  type        = string
}

variable "asg_security_group_id" {
  description = "Security group ID for ASG instances"
  type        = string
}

variable "jenkins_instance_profile" {
  description = "IAM instance profile for Jenkins master"
  type        = string
}

variable "asg_instance_profile" {
  description = "IAM instance profile for ASG instances"
  type        = string
}

variable "efs_file_system_id" {
  description = "EFS file system ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins master"
  type        = string
  default     = "t3.medium"
}

variable "asg_instance_type" {
  description = "Instance type for ASG instances"
  type        = string
  default     = "t4g.medium"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name"
  type        = string
  default     = "jenkins-dev"
}