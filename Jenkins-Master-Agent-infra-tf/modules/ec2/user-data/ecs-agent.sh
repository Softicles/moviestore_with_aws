#!/bin/bash

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Install EFS utilities
yum install -y amazon-efs-utils

# Create mount point for EFS
mkdir -p /mnt/efs

# Mount EFS
echo "${efs_file_system_id}.efs.${aws_region}.amazonaws.com:/ /mnt/efs efs defaults,_netdev" >> /etc/fstab
mount -a

# Create build cache directory
mkdir -p /mnt/efs/build_cache
chmod 755 /mnt/efs/build_cache

# Install ECS agent
yum install -y ecs-init
systemctl enable ecs

# Configure ECS agent
cat > /etc/ecs/ecs.config << EOF
ECS_CLUSTER=${cluster_name}
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
ECS_LOGFILE=/log/ecs-agent.log
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs"]
ECS_LOGLEVEL=info
ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
ECS_CONTAINER_STOP_TIMEOUT=30s
ECS_CONTAINER_START_TIMEOUT=3m
ECS_ENABLE_CONTAINER_METADATA=true
EOF

# Start ECS agent
systemctl start ecs

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Clean up
rm -rf awscliv2.zip aws/

# Install additional tools for builds
yum install -y git wget curl unzip

# Configure Docker daemon for better performance
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "awslogs",
  "log-opts": {
    "awslogs-region": "${aws_region}",
    "awslogs-group": "ecs-agent"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

# Restart Docker with new configuration
systemctl restart docker

echo "ECS agent installation completed!"