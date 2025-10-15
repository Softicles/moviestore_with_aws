# IAM Module Outputs

output "jenkins_instance_profile_name" {
  description = "Name of the Jenkins instance profile"
  value       = aws_iam_instance_profile.jenkins_master.name
}

output "jenkins_instance_profile_arn" {
  description = "ARN of the Jenkins instance profile"
  value       = aws_iam_instance_profile.jenkins_master.arn
}

output "jenkins_role_arn" {
  description = "ARN of the Jenkins master role"
  value       = aws_iam_role.jenkins_master.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "asg_instance_profile_name" {
  description = "Name of the ASG instance profile"
  value       = aws_iam_instance_profile.asg_instance.name
}

output "asg_instance_profile_arn" {
  description = "ARN of the ASG instance profile"
  value       = aws_iam_instance_profile.asg_instance.arn
}

output "asg_role_arn" {
  description = "ARN of the ASG instance role"
  value       = aws_iam_role.asg_instance.arn
}