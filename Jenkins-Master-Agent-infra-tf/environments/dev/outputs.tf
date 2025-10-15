# Development Environment Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.jenkins_infrastructure.vpc_id
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = module.jenkins_infrastructure.jenkins_url
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins master instance"
  value       = module.jenkins_infrastructure.jenkins_public_ip
}

output "jenkins_private_ip" {
  description = "Private IP of the Jenkins master instance"
  value       = module.jenkins_infrastructure.jenkins_private_ip
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.jenkins_infrastructure.ecs_cluster_name
}

output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = module.jenkins_infrastructure.efs_file_system_id
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.jenkins_infrastructure.ecs_task_execution_role_arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.jenkins_infrastructure.ecs_task_role_arn
}