# Security Groups Module

# Jenkins Master Security Group
resource "aws_security_group" "jenkins_master" {
  name_prefix = "${var.project_name}-${var.environment}-jenkins-master-"
  vpc_id      = var.vpc_id
  description = "Security group for Jenkins master instance"

  # HTTP access for Jenkins UI
  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins agent communication
  ingress {
    description = "Jenkins agent communication"
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-master-sg"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS ASG Security Group
resource "aws_security_group" "ecs_asg" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-asg-"
  vpc_id      = var.vpc_id
  description = "Security group for ECS ASG instances"

  # Jenkins agent communication
  ingress {
    description     = "Jenkins agent communication"
    from_port       = 50000
    to_port         = 50000
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_master.id]
  }

  # ECS agent communication
  ingress {
    description = "ECS agent communication"
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-asg-sg"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Fargate Security Group
resource "aws_security_group" "ecs_fargate" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-fargate-"
  vpc_id      = var.vpc_id
  description = "Security group for ECS Fargate tasks"

  # Jenkins agent communication
  ingress {
    description     = "Jenkins agent communication"
    from_port       = 50000
    to_port         = 50000
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_master.id]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-fargate-sg"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EFS Security Group
resource "aws_security_group" "efs" {
  name_prefix = "${var.project_name}-${var.environment}-efs-"
  vpc_id      = var.vpc_id
  description = "Security group for EFS file system"

  # NFS access from Jenkins master
  ingress {
    description     = "NFS from Jenkins master"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_master.id]
  }

  # NFS access from ECS instances
  ingress {
    description     = "NFS from ECS instances"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_asg.id]
  }

  # NFS access from Fargate tasks
  ingress {
    description     = "NFS from Fargate tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_fargate.id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-efs-sg"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}