# Outputs for Jenkins Infrastructure

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "jenkins_instance_id" {
  description = "ID of the Jenkins master instance"
  value       = module.ec2.jenkins_instance_id
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins master instance"
  value       = module.ec2.jenkins_public_ip
}

output "jenkins_private_ip" {
  description = "Private IP of the Jenkins master instance"
  value       = module.ec2.jenkins_private_ip
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${module.ec2.jenkins_public_ip}:8080"
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.ec2.asg_name
}

output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = module.efs.efs_file_system_id
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = module.efs.efs_dns_name
}

output "jenkins_instance_profile_arn" {
  description = "ARN of the Jenkins instance profile"
  value       = module.iam.jenkins_instance_profile_arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.iam.ecs_task_role_arn
}