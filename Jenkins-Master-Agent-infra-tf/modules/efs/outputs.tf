# EFS Module Outputs

output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.jenkins_cache.id
}

output "efs_file_system_arn" {
  description = "ARN of the EFS file system"
  value       = aws_efs_file_system.jenkins_cache.arn
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.jenkins_cache.dns_name
}

output "jenkins_access_point_id" {
  description = "ID of the Jenkins EFS access point"
  value       = aws_efs_access_point.jenkins.id
}

output "build_cache_access_point_id" {
  description = "ID of the build cache EFS access point"
  value       = aws_efs_access_point.build_cache.id
}

output "mount_target_ids" {
  description = "IDs of the EFS mount targets"
  value       = aws_efs_mount_target.jenkins_cache[*].id
}