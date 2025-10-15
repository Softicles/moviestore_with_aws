# Variables for Jenkins Infrastructure

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "jenkins-automation"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins master"
  type        = string
  default     = "t3.medium"
}

variable "asg_instance_type" {
  description = "EC2 instance type for ASG (Graviton-based)"
  type        = string
  default     = "t4g.medium"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = "jenkins-dev"
}

variable "jenkins_volume_size" {
  description = "EBS volume size for Jenkins master"
  type        = number
  default     = 50
}

variable "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
  default     = 0
}

variable "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
  default     = 10
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
  default     = 0
}