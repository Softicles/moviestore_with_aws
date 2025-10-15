# Main Terraform configuration for Jenkins Master-Agent Infrastructure
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr             = var.vpc_cidr
  availability_zones   = data.aws_availability_zones.available.names
  environment         = var.environment
  project_name        = var.project_name
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"
  
  vpc_id       = module.vpc.vpc_id
  environment  = var.environment
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

# IAM Module
module "iam" {
  source = "./modules/iam"
  
  environment  = var.environment
  project_name = var.project_name
  account_id   = data.aws_caller_identity.current.account_id
}

# EFS Module
module "efs" {
  source = "./modules/efs"
  
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  security_group_id   = module.security_groups.efs_security_group_id
  environment         = var.environment
  project_name        = var.project_name
}

# EC2 Module (Jenkins Master)
module "ec2" {
  source = "./modules/ec2"
  
  vpc_id                    = module.vpc.vpc_id
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  jenkins_security_group_id = module.security_groups.jenkins_security_group_id
  asg_security_group_id     = module.security_groups.asg_security_group_id
  jenkins_instance_profile  = module.iam.jenkins_instance_profile_name
  asg_instance_profile      = module.iam.asg_instance_profile_name
  efs_file_system_id        = module.efs.efs_file_system_id
  environment               = var.environment
  project_name              = var.project_name
  jenkins_instance_type     = var.jenkins_instance_type
  asg_instance_type         = var.asg_instance_type
  key_pair_name             = var.key_pair_name
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  environment           = var.environment
  project_name          = var.project_name
  asg_arn              = module.ec2.asg_arn
  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn        = module.iam.ecs_task_role_arn
}