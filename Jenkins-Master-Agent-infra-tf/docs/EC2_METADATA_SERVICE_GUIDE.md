# EC2 Metadata Service Integration with Jenkins Docker

## Overview

This guide shows how to properly integrate EC2 metadata service with Jenkins running in Docker containers, providing two main approaches: **Custom Dockerfile** and **Docker Compose with volume mounting**.

## Method 1: Custom Jenkins Dockerfile (RECOMMENDED)

### Why Custom Dockerfile?
- ✅ **Self-contained**: AWS CLI and configuration baked into the image
- ✅ **Portable**: Works across different environments
- ✅ **Version controlled**: Infrastructure as code for the container
- ✅ **Faster startup**: No runtime installation of tools
- ✅ **Consistent**: Same environment every time

### Complete Custom Dockerfile

```dockerfile
# terraform-jenkins-infrastructure/docker/jenkins-custom/Dockerfile
FROM jenkins/jenkins:lts

# Switch to root for package installation
USER root

# Install essential packages
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    jq \
    ca-certificates \
    git \
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

# Switch back to jenkins user
USER jenkins

# Create AWS configuration directory
RUN mkdir -p /var/jenkins_home/.aws

# Create AWS config file that uses EC2 instance metadata
RUN echo '[default]' > /var/jenkins_home/.aws/config \
    && echo 'region = us-west-2' >> /var/jenkins_home/.aws/config \
    && echo 'credential_source = Ec2InstanceMetadata' >> /var/jenkins_home/.aws/config \
    && echo 'output = json' >> /var/jenkins_home/.aws/config \
    && echo '' >> /var/jenkins_home/.aws/config \
    && echo '[profile jenkins]' >> /var/jenkins_home/.aws/config \
    && echo 'region = us-west-2' >> /var/jenkins_home/.aws/config \
    && echo 'credential_source = Ec2InstanceMetadata' >> /var/jenkins_home/.aws/config \
    && echo 'output = json' >> /var/jenkins_home/.aws/config

# Set AWS environment variables
ENV AWS_DEFAULT_REGION=us-west-2
ENV AWS_REGION=us-west-2
ENV AWS_EC2_METADATA_SERVICE_ENDPOINT=http://169.254.169.254
ENV AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE=IPv4

# Create a startup script to verify AWS credentials
RUN echo '#!/bin/bash' > /usr/local/bin/verify-aws.sh \
    && echo 'echo "=== AWS Credential Verification ==="' >> /usr/local/bin/verify-aws.sh \
    && echo 'echo "AWS CLI Version: $(aws --version)"' >> /usr/local/bin/verify-aws.sh \
    && echo 'echo "AWS Config:"' >> /usr/local/bin/verify-aws.sh \
    && echo 'aws configure list' >> /usr/local/bin/verify-aws.sh \
    && echo 'echo "AWS Identity:"' >> /usr/local/bin/verify-aws.sh \
    && echo 'aws sts get-caller-identity 2>/dev/null || echo "Warning: AWS credentials not available yet"' >> /usr/local/bin/verify-aws.sh \
    && echo 'echo "================================="' >> /usr/local/bin/verify-aws.sh \
    && chmod +x /usr/local/bin/verify-aws.sh

# Optional: Install common Jenkins plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Add custom init script
COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/aws-setup.groovy
```

### Docker Compose for Custom Image

```yaml
# docker-compose.yml
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
      - AWS_DEFAULT_REGION=us-west-2
      - AWS_REGION=us-west-2
      - AWS_EC2_METADATA_SERVICE_ENDPOINT=http://169.254.169.254
      - AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE=IPv4
    user: "1000:1000"
    # Enable access to EC2 metadata service
    network_mode: "host"
    
    # Health check to verify AWS access
    healthcheck:
      test: ["CMD", "/usr/local/bin/verify-aws.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

### Building and Using Custom Image

```bash
# In user data script
cd /home/ec2-user

# Create Dockerfile with region substitution
cat > Dockerfile << EOF
FROM jenkins/jenkins:lts

USER root

# Install AWS CLI v2 and tools
RUN apt-get update && apt-get install -y curl unzip jq ca-certificates git \\
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \\
    && unzip awscliv2.zip && ./aws/install \\
    && rm -rf awscliv2.zip aws/ /var/lib/apt/lists/*

USER jenkins

# Create AWS config for EC2 metadata service
RUN mkdir -p /var/jenkins_home/.aws \\
    && echo '[default]' > /var/jenkins_home/.aws/config \\
    && echo 'region = ${aws_region}' >> /var/jenkins_home/.aws/config \\
    && echo 'credential_source = Ec2InstanceMetadata' >> /var/jenkins_home/.aws/config \\
    && echo 'output = json' >> /var/jenkins_home/.aws/config

ENV AWS_DEFAULT_REGION=${aws_region}
ENV AWS_REGION=${aws_region}
ENV AWS_EC2_METADATA_SERVICE_ENDPOINT=http://169.254.169.254
ENV AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE=IPv4
EOF

# Build the custom image
docker build -t jenkins-aws:lts .

# Start with docker-compose
docker-compose up -d
```

## Method 2: Standard Jenkins Image with Volume Mounting

### Why Volume Mounting?
- ✅ **Quick setup**: Uses official Jenkins image
- ✅ **Flexible**: Easy to modify AWS config without rebuilding
- ✅ **Debugging**: Can inspect/modify config on host
- ⚠️ **Runtime dependency**: Requires host-side AWS config setup

### Docker Compose with Volume Mounting

```yaml
# docker-compose-standard.yml
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
      # Mount AWS config from host (read-only for security)
      - /home/ec2-user/.aws:/var/jenkins_home/.aws:ro
      # Optional: Mount AWS CLI binary if not installing in container
      - /usr/local/bin/aws:/usr/local/bin/aws:ro
    environment:
      - JENKINS_OPTS=--httpPort=8080
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
      - AWS_DEFAULT_REGION=us-west-2
      - AWS_REGION=us-west-2
      - AWS_EC2_METADATA_SERVICE_ENDPOINT=http://169.254.169.254
      - AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE=IPv4
    user: "1000:1000"
    # Enable metadata service access
    network_mode: "host"
    
    # Health check
    healthcheck:
      test: ["CMD-SHELL", "aws sts get-caller-identity || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

### Host AWS Configuration Setup

```bash
# Create AWS config directory
mkdir -p /home/ec2-user/.aws

# Create comprehensive AWS config
cat > /home/ec2-user/.aws/config << EOF
[default]
region = ${aws_region}
credential_source = Ec2InstanceMetadata
output = json
cli_pager = 

[profile jenkins]
region = ${aws_region}
credential_source = Ec2InstanceMetadata
output = json

[profile ecs-agent]
region = ${aws_region}
credential_source = Ec2InstanceMetadata
output = json
role_arn = arn:aws:iam::ACCOUNT:role/jenkins-ecs-task-role
EOF

# Set proper ownership and permissions
chown -R 1000:1000 /home/ec2-user/.aws
chmod 755 /home/ec2-user/.aws
chmod 644 /home/ec2-user/.aws/config
```

## Network Configuration Options

### Option 1: Host Networking (Recommended)

```yaml
services:
  jenkins:
    network_mode: "host"
```

**Advantages:**
- ✅ Direct access to EC2 metadata service (169.254.169.254)
- ✅ No network translation issues
- ✅ Simplest configuration

**Disadvantages:**
- ⚠️ Less container isolation
- ⚠️ Port conflicts possible

### Option 2: Bridge Networking with Extra Hosts

```yaml
services:
  jenkins:
    extra_hosts:
      - "metadata.google.internal:169.254.169.254"
      - "instance-data:169.254.169.254"
    networks:
      - jenkins

networks:
  jenkins:
    driver: bridge
```

**Advantages:**
- ✅ Better container isolation
- ✅ Standard Docker networking

**Disadvantages:**
- ⚠️ More complex configuration
- ⚠️ May require additional routing rules

### Option 3: Custom Network with Metadata Proxy

```yaml
services:
  metadata-proxy:
    image: amazon/aws-cli:latest
    command: |
      sh -c "
        while true; do
          nc -l -p 8080 -c 'curl -s http://169.254.169.254$$REQUEST_URI'
        done
      "
    networks:
      - jenkins

  jenkins:
    depends_on:
      - metadata-proxy
    environment:
      - AWS_EC2_METADATA_SERVICE_ENDPOINT=http://metadata-proxy:8080
    networks:
      - jenkins
```

## Testing and Verification

### 1. Container-Level Testing

```bash
# Access Jenkins container
docker exec -it jenkins-master bash

# Test AWS CLI installation
aws --version

# Test AWS configuration
aws configure list

# Test credentials
aws sts get-caller-identity

# Test ECS access
aws ecs list-clusters

# Test ECR access
aws ecr get-login-token --region us-west-2
```

### 2. Jenkins Pipeline Testing

```groovy
pipeline {
    agent any
    
    stages {
        stage('AWS Credential Test') {
            steps {
                script {
                    // Test AWS CLI
                    sh 'aws --version'
                    
                    // Test credentials
                    def identity = sh(
                        script: 'aws sts get-caller-identity',
                        returnStdout: true
                    ).trim()
                    echo "AWS Identity: ${identity}"
                    
                    // Test ECS access
                    def clusters = sh(
                        script: 'aws ecs list-clusters --query "clusterArns" --output text',
                        returnStdout: true
                    ).trim()
                    echo "ECS Clusters: ${clusters}"
                    
                    // Test ECR access
                    sh 'aws ecr get-login-token --region us-west-2'
                }
            }
        }
        
        stage('ECS Agent Test') {
            agent {
                ecs {
                    inheritFrom 'fargate-agent'
                    image 'jenkins/inbound-agent:latest'
                }
            }
            steps {
                echo 'Testing ECS agent provisioning'
                sh 'echo "Running on ECS Fargate agent"'
            }
        }
    }
}
```

### 3. Automated Health Checks

```bash
# Create health check script
cat > /home/ec2-user/health-check.sh << 'EOF'
#!/bin/bash

echo "=== Jenkins AWS Health Check ==="

# Check if Jenkins is running
if ! docker ps | grep -q jenkins-master; then
    echo "❌ Jenkins container not running"
    exit 1
fi

# Check AWS credentials in container
if ! docker exec jenkins-master aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS credentials not working in Jenkins container"
    exit 1
fi

# Check ECS access
if ! docker exec jenkins-master aws ecs list-clusters > /dev/null 2>&1; then
    echo "❌ ECS access not working"
    exit 1
fi

echo "✅ All checks passed"
EOF

chmod +x /home/ec2-user/health-check.sh

# Add to crontab for regular checks
echo "*/5 * * * * /home/ec2-user/health-check.sh >> /var/log/jenkins-health.log 2>&1" | crontab -
```

## Troubleshooting Common Issues

### Issue 1: "Unable to locate credentials"

**Diagnosis:**
```bash
# Check metadata service access
docker exec jenkins-master curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Check AWS config
docker exec jenkins-master cat /var/jenkins_home/.aws/config

# Check environment variables
docker exec jenkins-master env | grep AWS
```

**Solutions:**
```bash
# Ensure host networking
network_mode: "host"

# Or add metadata service endpoint
environment:
  - AWS_EC2_METADATA_SERVICE_ENDPOINT=http://169.254.169.254
```

### Issue 2: "Network timeout accessing metadata service"

**Diagnosis:**
```bash
# Test from host
curl -s http://169.254.169.254/latest/meta-data/

# Test from container
docker exec jenkins-master curl -s http://169.254.169.254/latest/meta-data/
```

**Solutions:**
```bash
# Use host networking
network_mode: "host"

# Or configure extra hosts
extra_hosts:
  - "metadata.google.internal:169.254.169.254"
```

### Issue 3: "Permission denied for AWS operations"

**Diagnosis:**
```bash
# Check IAM role
aws sts get-caller-identity

# Check role policies
aws iam list-attached-role-policies --role-name YourJenkinsRole
```

**Solutions:**
```bash
# Verify IAM role attachment to EC2 instance
aws ec2 describe-instances --instance-ids i-1234567890abcdef0 \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# Check role permissions
aws iam get-role-policy --role-name YourJenkinsRole --policy-name YourPolicy
```

## Production Recommendations

### 1. Use Custom Dockerfile
- Build once, run anywhere
- Version controlled configuration
- Faster container startup

### 2. Implement Health Checks
- Monitor AWS credential availability
- Alert on authentication failures
- Automated recovery procedures

### 3. Security Best Practices
- Use read-only volume mounts
- Implement least privilege IAM policies
- Enable CloudTrail for API monitoring

### 4. Performance Optimization
- Cache AWS CLI responses
- Use regional endpoints
- Implement connection pooling

This comprehensive approach ensures reliable AWS integration with your Jenkins Docker containers while maintaining security and performance best practices.