# Development Environment Main Configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Use the main module
module "jenkins_infrastructure" {
  source = "../../"

  aws_region            = var.aws_region
  environment           = var.environment
  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  jenkins_instance_type = var.jenkins_instance_type
  asg_instance_type     = var.asg_instance_type
  key_pair_name         = var.key_pair_name
  jenkins_volume_size   = var.jenkins_volume_size
  asg_min_size          = var.asg_min_size
  asg_max_size          = var.asg_max_size
  asg_desired_capacity  = var.asg_desired_capacity
}