#!/bin/bash

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install EFS utilities
yum install -y amazon-efs-utils

# Create mount point for EFS
mkdir -p /mnt/efs
mkdir -p /var/jenkins_home

# Mount EFS
echo "${efs_file_system_id}.efs.${aws_region}.amazonaws.com:/ /mnt/efs efs defaults,_netdev" >> /etc/fstab
mount -a

# Create Jenkins directories on EFS
mkdir -p /mnt/efs/jenkins_home
mkdir -p /mnt/efs/build_cache

# Set permissions
chown -R 1000:1000 /mnt/efs/jenkins_home
chown -R 1000:1000 /mnt/efs/build_cache

# Bind mount Jenkins home
echo "/mnt/efs/jenkins_home /var/jenkins_home none bind 0 0" >> /etc/fstab
mount -a

# Option 1: Use custom Jenkins image (recommended for production)
# Build custom Jenkins image with AWS integration
cat > /home/ec2-user/Dockerfile << 'EOF'
FROM jenkins/jenkins:lts

USER root

# Install AWS CLI v2 and tools
RUN apt-get update && apt-get install -y curl unzip jq ca-certificates \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip && ./aws/install \
    && rm -rf awscliv2.zip aws/ /var/lib/apt/lists/*

# Install Docker CLI for DinD scenarios
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

USER jenkins

# Create AWS config for EC2 metadata service
RUN mkdir -p /var/jenkins_home/.aws \
    && echo '[default]' > /var/jenkins_home/.aws/config \
    && echo 'region = ${aws_region}' >> /var/jenkins_home/.aws/config \
    && echo 'credential_source = Ec2InstanceMetadata' >> /var/jenkins_home/.aws/config \
    && echo 'output = json' >> /var/jenkins_home/.aws/config

ENV AWS_DEFAULT_REGION=${aws_region}
ENV AWS_REGION=${aws_region}
ENV AWS_EC2_METADATA_SERVICE_ENDPOINT=http://169.254.169.254
ENV AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE=IPv4
EOF

# Build custom image
docker build -t jenkins-aws:lts /home/ec2-user/

# Create docker-compose.yml using custom image
cat > /home/ec2-user/docker-compose.yml << 'EOF'
version: '3.8'

services:
  jenkins:
    image: jenkins-aws:lts
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
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false -Dhudson.model.DirectoryBrowserSupport.CSP=
      - AWS_DEFAULT_REGION=${aws_region}
      - AWS_REGION=${aws_region}
      - AWS_EC2_METADATA_SERVICE_ENDPOINT=http://169.254.169.254
      - AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE=IPv4
    user: "1000:1000"
    # Method 1: Host networking (full metadata service access)
    network_mode: "host"
    
    # Method 2: Bridge networking with metadata service access
    # Uncomment below and comment network_mode above for bridge networking
    # extra_hosts:
    #   - "metadata.google.internal:169.254.169.254"
    # networks:
    #   - jenkins

# Uncomment for bridge networking
# networks:
#   jenkins:
#     driver: bridge
EOF

# Alternative: Standard Jenkins image with mounted AWS config
cat > /home/ec2-user/docker-compose-standard.yml << 'EOF'
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins-master
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - /var/jenkins_home:/var/jenkins_home
      - /mnt/efs/build_cache:/var/build_cache
      - /var/run/docker.sock:/var/run/docker.sock
      # Mount AWS config from host
      - /home/ec2-user/.aws:/var/jenkins_home/.aws:ro
    environment:
      - JENKINS_OPTS=--httpPort=8080
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
      - AWS_DEFAULT_REGION=${aws_region}
      - AWS_REGION=${aws_region}
      - AWS_EC2_METADATA_SERVICE_ENDPOINT=http://169.254.169.254
      - AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE=IPv4
    user: "1000:1000"
    # Enable metadata service access
    network_mode: "host"
EOF

# Create AWS config file for standard image approach
mkdir -p /home/ec2-user/.aws
cat > /home/ec2-user/.aws/config << EOF
[default]
region = ${aws_region}
credential_source = Ec2InstanceMetadata
output = json

[profile jenkins]
region = ${aws_region}
credential_source = Ec2InstanceMetadata
output = json
EOF

# Set proper ownership
chown -R 1000:1000 /home/ec2-user/.aws

# Set ownership of docker-compose file
chown ec2-user:ec2-user /home/ec2-user/docker-compose.yml

# Start Jenkins using docker-compose
cd /home/ec2-user
docker-compose up -d

# Create systemd service for Jenkins
cat > /etc/systemd/system/jenkins-docker.service << 'EOF'
[Unit]
Description=Jenkins Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ec2-user
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl enable jenkins-docker.service
systemctl start jenkins-docker.service

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Clean up
rm -rf awscliv2.zip aws/

# Wait for Jenkins to start and get initial admin password
sleep 60
if [ -f /var/jenkins_home/secrets/initialAdminPassword ]; then
    echo "Jenkins initial admin password:" > /home/ec2-user/jenkins-password.txt
    cat /var/jenkins_home/secrets/initialAdminPassword >> /home/ec2-user/jenkins-password.txt
    chown ec2-user:ec2-user /home/ec2-user/jenkins-password.txt
fi

echo "Jenkins installation completed!"