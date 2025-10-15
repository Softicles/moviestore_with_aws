# ECS Module

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-cluster"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECS Capacity Provider for ASG
resource "aws_ecs_capacity_provider" "asg" {
  name = "${var.project_name}-${var.environment}-asg"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = var.asg_arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-asg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associate Capacity Providers with Cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT",
    aws_ecs_capacity_provider.asg.name
  ]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    base              = 0
    weight            = 50
    capacity_provider = "FARGATE_SPOT"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group for ECS Agent
resource "aws_cloudwatch_log_group" "ecs_agent" {
  name              = "ecs-agent"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-agent-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Sample Task Definition for Jenkins Agent
resource "aws_ecs_task_definition" "jenkins_agent" {
  family                   = "${var.project_name}-${var.environment}-jenkins-agent"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn           = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "jenkins-agent"
      image = "jenkins/inbound-agent:latest"
      
      essential = true
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "jenkins-agent"
        }
      }
      
      environment = [
        {
          name  = "JENKINS_URL"
          value = "http://jenkins-master:8080"
        }
      ]
    }
  ])

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-agent-task"
    Environment = var.environment
    Project     = var.project_name
  }
}

data "aws_region" "current" {}