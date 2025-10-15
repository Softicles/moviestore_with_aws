# IAM Module

# Jenkins Master IAM Role
resource "aws_iam_role" "jenkins_master" {
  name = "${var.project_name}-${var.environment}-jenkins-master-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-master-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Jenkins Master IAM Policy
resource "aws_iam_policy" "jenkins_master" {
  name        = "${var.project_name}-${var.environment}-jenkins-master-policy"
  description = "IAM policy for Jenkins master"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:*",
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeRegions",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "iam:PassRole",
          "elasticfilesystem:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-master-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach policy to Jenkins master role
resource "aws_iam_role_policy_attachment" "jenkins_master" {
  role       = aws_iam_role.jenkins_master.name
  policy_arn = aws_iam_policy.jenkins_master.arn
}

# Jenkins Master Instance Profile
resource "aws_iam_instance_profile" "jenkins_master" {
  name = "${var.project_name}-${var.environment}-jenkins-master-profile"
  role = aws_iam_role.jenkins_master.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-master-profile"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-execution-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECS Task Policy
resource "aws_iam_policy" "ecs_task" {
  name        = "${var.project_name}-${var.environment}-ecs-task-policy"
  description = "IAM policy for ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "elasticfilesystem:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_task.arn
}

# ASG Instance Role
resource "aws_iam_role" "asg_instance" {
  name = "${var.project_name}-${var.environment}-asg-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-asg-instance-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach AWS managed policy for ECS container instance
resource "aws_iam_role_policy_attachment" "asg_instance_ecs" {
  role       = aws_iam_role.asg_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# ASG Instance Profile
resource "aws_iam_instance_profile" "asg_instance" {
  name = "${var.project_name}-${var.environment}-asg-instance-profile"
  role = aws_iam_role.asg_instance.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-asg-instance-profile"
    Environment = var.environment
    Project     = var.project_name
  }
}