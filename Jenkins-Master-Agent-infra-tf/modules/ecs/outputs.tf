# ECS Module Outputs


output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

# Built-in capacity providers: return literal names
output "fargate_capacity_provider_name" {
  description = "Name of the AWS-managed FARGATE capacity provider"
  value       = "FARGATE"
}

output "fargate_spot_capacity_provider_name" {
  description = "Name of the AWS-managed FARGATE_SPOT capacity provider"
  value       = "FARGATE_SPOT"
}

# Your custom ASG-backed capacity provider (declared in this module)
output "asg_capacity_provider_name" {
  description = "Name of the ASG capacity provider"
  value       = aws_ecs_capacity_provider.asg.name
}

# Helpful: what did we actually associate on the cluster?
output "cluster_capacity_providers" {
  description = "All capacity providers associated to the cluster"
  value       = aws_ecs_cluster_capacity_providers.main.capacity_providers
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "jenkins_agent_task_definition_arn" {
  description = "ARN of the Jenkins agent task definition"
  value       = aws_ecs_task_definition.jenkins_agent.arn
}