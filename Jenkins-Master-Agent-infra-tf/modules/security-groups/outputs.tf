# Security Groups Module Outputs

output "jenkins_security_group_id" {
  description = "ID of the Jenkins master security group"
  value       = aws_security_group.jenkins_master.id
}

output "asg_security_group_id" {
  description = "ID of the ECS ASG security group"
  value       = aws_security_group.ecs_asg.id
}

output "fargate_security_group_id" {
  description = "ID of the ECS Fargate security group"
  value       = aws_security_group.ecs_fargate.id
}

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = aws_security_group.efs.id
}