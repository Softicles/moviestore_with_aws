# EC2 Module Outputs

output "jenkins_instance_id" {
  description = "ID of the Jenkins master instance"
  value       = aws_instance.jenkins_master.id
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins master instance"
  value       = aws_instance.jenkins_master.public_ip
}

output "jenkins_private_ip" {
  description = "Private IP of the Jenkins master instance"
  value       = aws_instance.jenkins_master.private_ip
}

output "jenkins_public_dns" {
  description = "Public DNS of the Jenkins master instance"
  value       = aws_instance.jenkins_master.public_dns
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.ecs.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.ecs.arn
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.ecs_asg.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.ecs_asg.latest_version
}