# EC2 Module

# Data sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "amazon_linux_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Jenkins Master User Data
locals {
  jenkins_user_data = base64encode(templatefile("${path.module}/user-data/jenkins-master.sh", {
    efs_file_system_id = var.efs_file_system_id
    aws_region         = data.aws_region.current.name
  }))
  
  asg_user_data = base64encode(templatefile("${path.module}/user-data/ecs-agent.sh", {
    cluster_name       = "${var.project_name}-${var.environment}-cluster"
    efs_file_system_id = var.efs_file_system_id
    aws_region         = data.aws_region.current.name
  }))
}

data "aws_region" "current" {}

# Jenkins Master Instance
resource "aws_instance" "jenkins_master" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.jenkins_instance_type
  key_name              = var.key_pair_name != "" ? var.key_pair_name : null
  vpc_security_group_ids = [var.jenkins_security_group_id]
  subnet_id             = var.public_subnet_ids[0]
  iam_instance_profile  = var.jenkins_instance_profile

  user_data = local.jenkins_user_data

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
    encrypted   = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-master"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Jenkins Master"
  }
}

# Launch Template for ASG
resource "aws_launch_template" "ecs_asg" {
  name_prefix   = "${var.project_name}-${var.environment}-ecs-"
  image_id      = data.aws_ami.amazon_linux_arm.id
  instance_type = var.asg_instance_type
  key_name      = var.key_pair_name != "" ? var.key_pair_name : null

  vpc_security_group_ids = [var.asg_security_group_id]

  iam_instance_profile {
    name = var.asg_instance_profile
  }

  user_data = local.asg_user_data

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type = "gp3"
      volume_size = 30
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}-ecs-instance"
      Environment = var.environment
      Project     = var.project_name
      Type        = "ECS Instance"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-launch-template"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-${var.environment}-ecs-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = []
  health_check_type   = "EC2"
  health_check_grace_period = 300

  min_size         = 0
  max_size         = 10
  desired_capacity = 0

  launch_template {
    id      = aws_launch_template.ecs_asg.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-ecs-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = false
  }

  lifecycle {
    create_before_destroy = true
  }
}