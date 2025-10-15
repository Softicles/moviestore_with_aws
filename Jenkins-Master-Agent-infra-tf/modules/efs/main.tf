# EFS Module

# EFS File System
resource "aws_efs_file_system" "jenkins_cache" {
  creation_token = "${var.project_name}-${var.environment}-jenkins-cache"
  
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100
  
  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-cache"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Jenkins Cache"
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "jenkins_cache" {
  count = length(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.jenkins_cache.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [var.security_group_id]
}

# EFS Access Point for Jenkins
resource "aws_efs_access_point" "jenkins" {
  file_system_id = aws_efs_file_system.jenkins_cache.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/jenkins"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-access-point"
    Environment = var.environment
    Project     = var.project_name
  }
}

# EFS Access Point for Build Cache
resource "aws_efs_access_point" "build_cache" {
  file_system_id = aws_efs_file_system.jenkins_cache.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/build-cache"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-build-cache-access-point"
    Environment = var.environment
    Project     = var.project_name
  }
}