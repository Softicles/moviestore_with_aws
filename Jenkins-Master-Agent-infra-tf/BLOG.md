# Complete Infrastructure as Code Implementation

## Infrastructure Architecture Overview

Our Terraform-based infrastructure creates a comprehensive, production-ready environment:

```bash
┌─────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                   │
│  ┌─────────────────┐              ┌─────────────────┐      │
│  │  Public Subnet  │              │  Public Subnet  │      │
│  │   (AZ-1)        │              │   (AZ-2)        │      │
│  │ ┌─────────────┐ │              │ ┌─────────────┐ │      │
│  │ │Jenkins      │ │              │ │ NAT Gateway │ │      │
│  │ │Master       │ │              │ │             │ │      │
│  │ └─────────────┘ │              │ └─────────────┘ │      │
│  └─────────────────┘              └─────────────────┘      │
│  ┌─────────────────┐              ┌─────────────────┐      │
│  │ Private Subnet  │              │ Private Subnet  │      │
│  │   (AZ-1)        │              │   (AZ-2)        │      │
│  │ ┌─────────────┐ │              │ ┌─────────────┐ │      │
│  │ │ECS Agents   │ │              │ │ECS Agents   │ │      │
│  │ │(ASG)        │ │              │ │(Fargate)    │ │      │
│  │ └─────────────┘ │              │ └─────────────┘ │      │
│  └─────────────────┘              └─────────────────┘      │
│                    ┌─────────────────┐                     │
│                    │       EFS       │                     │
│                    │  (Build Cache)  │                     │
│                    └─────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

## Terraform Module Structure

Our infrastructure follows a modular approach for maintainability and reusability:

```bash
terraform-jenkins-infrastructure/
├── main.tf                    # Root module orchestration
├── variables.tf               # Configuration variables
├── outputs.tf                 # Infrastructure outputs
├── modules/
│   ├── vpc/                   # VPC, subnets, routing
│   ├── security-groups/       # Security groups
│   ├── iam/                   # IAM roles and policies
│   ├── efs/                   # EFS file system
│   ├── ec2/                   # Jenkins master and ASG
│   └── ecs/                   # ECS cluster configuration
└── environments/dev/          # Environment-specific configs
```

Custom Jenkins Image

Why, we are using a custom jenkins image here, because we need to passing in the AWS EC2 instance metadata to the Jenkins container in-order to assume the IAM role attached to the Jenkins Master EC2 instance.

```Dockerfile
# Custom Jenkins Docker Image with AWS Integration
FROM jenkins/jenkins:lts

# Switch to root to install packages
USER root

# Install AWS CLI v2 and additional tools
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws/

# Install Docker CLI (for Docker-in-Docker scenarios)
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Create AWS config directory
RUN mkdir -p /var/jenkins_home/.aws

# Create AWS config file that uses EC2 instance metadata
RUN echo '[default]' > /var/jenkins_home/.aws/config \
    && echo 'region = us-west-2' >> /var/jenkins_home/.aws/config \
    && echo 'credential_source = Ec2InstanceMetadata' >> /var/jenkins_home/.aws/config \
    && echo 'output = json' >> /var/jenkins_home/.aws/config

# Set proper ownership
RUN chown -R jenkins:jenkins /var/jenkins_home/.aws

# Create a script to verify AWS credentials on startup
RUN echo '#!/bin/bash' > /usr/local/bin/verify-aws-credentials.sh \
    && echo 'echo "Verifying AWS credentials..."' >> /usr/local/bin/verify-aws-credentials.sh \
    && echo 'aws sts get-caller-identity || echo "Warning: AWS credentials not available"' >> /usr/local/bin/verify-aws-credentials.sh \
    && chmod +x /usr/local/bin/verify-aws-credentials.sh

# Install common Jenkins plugins (optional)
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Switch back to jenkins user
USER jenkins

# Set environment variables for AWS
ENV AWS_DEFAULT_REGION=us-west-2
ENV AWS_REGION=us-west-2
ENV AWS_EC2_METADATA_SERVICE_ENDPOINT=http://169.254.169.254
ENV AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE=IPv4

# Verify AWS setup on container start
RUN echo 'verify-aws-credentials.sh' >> /var/jenkins_home/init.groovy.d/aws-verify.groovy
```

In the same path you provide plugins you want in order to save time, in the initial setup of Jenkins. We can enter our plugins in a file named plugins.txt

```bash
# Essential Jenkins plugins for AWS integration
amazon-ecs:1.49
aws-credentials:191.vcb_f183ce58b_9
pipeline-stage-view:2.25
workflow-aggregator:590.v6a_d052e5a_a_b_5
git:4.13.0
github:1.37.0
docker-workflow:563.vd5d2e5c4007f
pipeline-aws:1.43
ec2:1.72
blueocean:1.25.8
configuration-as-code:1569.vb_72405b_80249
job-dsl:1.81
```

## Step-by-Step Implementation Guide

### Step 1: Infrastructure Foundation with Terraform

#### VPC and Networking Setup

Our VPC module creates a robust networking foundation:

```h
# VPC with multi-AZ setup
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Public subnets for Jenkins master and NAT gateways
resource "aws_subnet" "public" {
  count = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
}

# Private subnets for ECS agents
resource "aws_subnet" "private" {
  count = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]
}
```

#### Security Groups Configuration

Comprehensive security groups ensure proper communication:

```terraform
# Jenkins Master Security Group
resource "aws_security_group" "jenkins_master" {
  name_prefix = "${var.project_name}-${var.environment}-jenkins-master-"
  vpc_id      = var.vpc_id

  # Jenkins UI access
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins agent communication
  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}
```

### Step 2: Jenkins Master with Docker Compose

#### EC2 Instance with Automated Setup

The Jenkins master is deployed on EC2 with complete automation:

```h
resource "aws_instance" "jenkins_master" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.jenkins_instance_type
  vpc_security_group_ids = [var.jenkins_security_group_id]
  subnet_id             = var.public_subnet_ids[0]
  iam_instance_profile  = var.jenkins_instance_profile
  user_data = base64encode(templatefile("${path.module}/user-data/jenkins-master.sh", {
    efs_file_system_id = var.efs_file_system_id
    aws_region         = data.aws_region.current.name
    jenkins_image      = var.jenkins_ecr_repo
  }))
}
```

#### Automated Jenkins Installation Script

The user data script handles complete Jenkins setup:

```bash
#!/bin/bash
# Install Docker and Docker Compose
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Mount EFS for persistent storage
yum install -y amazon-efs-utils
mkdir -p /mnt/efs /var/jenkins_home
echo "${efs_file_system_id}.efs.${aws_region}.amazonaws.com:/ /mnt/efs efs defaults,_netdev" >> /etc/fstab
mount -a

# Create Docker Compose configuration
cat > /home/ec2-user/docker-compose.yml << 'EOF'
version: '3.8'
services:
  jenkins:
    image: ${jenkins_image}
    container_name: jenkins-master
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - /var/jenkins_home:/var/jenkins_home
      - /mnt/efs/build_cache:/var/build_cache
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JENKINS_OPTS=--httpPort=8080
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
    user: "1000:1000"
EOF

# Start Jenkins
cd /home/ec2-user && docker-compose up -d
```

### Step 3: EFS for Persistent Storage and Caching

#### EFS Configuration with Access Points

```h
resource "aws_efs_file_system" "jenkins_cache" {
  creation_token = "${var.project_name}-${var.environment}-jenkins-cache"
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100
  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

# Access point for Jenkins home
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
}

# Access point for build cache
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
}
```

### Step 4: ECS Cluster with Multiple Capacity Providers

#### ECS Cluster Configuration

```h
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Fargate Capacity Provider
resource "aws_ecs_capacity_provider" "fargate" {
  name = "${var.project_name}-${var.environment}-fargate"
}

# Fargate Spot Capacity Provider
resource "aws_ecs_capacity_provider" "fargate_spot" {
  name = "${var.project_name}-${var.environment}-fargate-spot"
}

# EC2 ASG Capacity Provider
resource "aws_ecs_capacity_provider" "asg" {
  name = "${var.project_name}-${var.environment}-asg"
  
  auto_scaling_group_provider {
    auto_scaling_group_arn = var.asg_arn
    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80
    }
  }
}

# Associate all capacity providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT", aws_ecs_capacity_provider.asg.name]
  
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
  
  default_capacity_provider_strategy {
    base              = 0
    weight            = 25
    capacity_provider = aws_ecs_capacity_provider.asg.name
  }
}
```

### Step 5: Auto Scaling Group with Graviton Instances

#### Launch Template for Cost-Optimized Instances

```h
resource "aws_launch_template" "ecs_asg" {
  name_prefix   = "${var.project_name}-${var.environment}-ecs-"
  image_id      = data.aws_ami.amazon_linux_arm.id  # Graviton-based AMI
  instance_type = var.asg_instance_type  # t4g.medium
  
  iam_instance_profile {
    name = var.asg_instance_profile
  }
  
  user_data = base64encode(templatefile("${path.module}/user-data/ecs-agent.sh", {
    cluster_name       = "${var.project_name}-${var.environment}-cluster"
    efs_file_system_id = var.efs_file_system_id
    aws_region         = data.aws_region.current.name
  }))
}

resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-${var.environment}-ecs-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size         = 0
  max_size         = 10
  desired_capacity = 0  # Scales on demand
  
  launch_template {
    id      = aws_launch_template.ecs_asg.id
    version = "$Latest"
  }
}
```

### Step 6: IAM Roles and Policies

#### Comprehensive IAM Setup

```h
# Jenkins Master Role
resource "aws_iam_role" "jenkins_master" {
  name = "${var.project_name}-${var.environment}-jenkins-master-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# ECS Task Role for build operations
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-${var.environment}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}
```

## Deployment Guide

### Quick Start

1. Clone the Infrastructure Repository:

    ```bash
    git clone <repository-url>
    cd terraform-jenkins-infrastructure/environments/dev
    ```

2. Configure Variables: Edit `terraform.tfvars`:

    ```h
    aws_region       = "us-west-2"
    environment      = "dev"
    project_name     = "jenkins-automation"
    jenkins_ecr_repo = "<enter-your-custom-jenkins-image-url>"
    key_pair_name    = "your-key-pair"  # Optional for SSH access
    ```

3. Deploy Infrastructure:

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

4. Access Jenkins:

    ```bash
    # Get Jenkins URL from outputs
    terraform output jenkins_url

    # Get initial admin password
    ssh ec2-user@$(terraform output jenkins_public_ip)
    sudo cat /var/jenkins_home/secrets/initialAdminPassword
    ```

## Cost Optimization Strategies

### 1. Resource Right-Sizing

```h

# Different instance types for different workloads
variable "agent_configurations" {
  default = {
    small = {
      cpu    = 256
      memory = 512
    }
    medium = {
      cpu    = 512
      memory = 1024
    }
    large = {
      cpu    = 1024
      memory = 2048
    }
  }
}
```

### 2. Auto-Scaling Optimization

```h
# ASG with aggressive scale-down
resource "aws_autoscaling_group" "ecs" {
  min_size         = 0
  max_size         = 20
  desired_capacity = 0
  
  # Scale down quickly when not needed
  default_cooldown = 60
  
  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = false
  }
}
```

## Monitoring and Observability

### CloudWatch Integration

```h
# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "jenkins" {
  name              = "/jenkins/${var.project_name}-${var.environment}"
  retention_in_days = 14
}
```

### Monitoring Dashboard

```h
resource "aws_cloudwatch_dashboard" "jenkins" {
  dashboard_name = "${var.project_name}-${var.environment}-jenkins"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ECS Cluster Metrics"
        }
      }
    ]
  })
}
```

## Security Best Practices

### 1. Network Security

* Jenkins master in public subnet (can be moved to private with ALB)
* ECS agents in private subnets only
* Security groups with least privilege access
* VPC Flow Logs enabled

### 2. Data Security

* EFS and EBS encryption at rest
* Secrets management via AWS Secrets Manager
* IAM roles with minimal required permissions

### 3. Container Security

* Regular base image updates
* Vulnerability scanning with ECR
* Non-root container execution where possible