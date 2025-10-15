# IAM Credentials for Jenkins Docker Container

## The Problem

When Jenkins runs inside a Docker container on an EC2 instance with an attached IAM role, the container doesn't automatically inherit the IAM permissions. This is because Docker containers are isolated from the host system by default.

## Solution Methods

### Method 1: EC2 Instance Metadata Service (RECOMMENDED)

This is the most secure and AWS-native approach.

#### How it works:
1. EC2 instance has an IAM role attached
2. Jenkins container accesses the EC2 metadata service at `169.254.169.254`
3. AWS SDK automatically retrieves temporary credentials from the metadata service

#### Implementation:

```yaml
# docker-compose.yml
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
      - /home/ec2-user/.aws:/var/jenkins_home/.aws:ro
    environment:
      - JENKINS_OPTS=--httpPort=8080
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
      - AWS_DEFAULT_REGION=us-west-2
      - AWS_REGION=us-west-2
    user: "1000:1000"
    # Enable access to EC2 metadata service
    network_mode: "host"
```

#### AWS Config File:
```bash
# /home/ec2-user/.aws/config
[default]
region = us-west-2
credential_source = Ec2InstanceMetadata
```

#### Advantages:
- ✅ Most secure (no static credentials)
- ✅ Automatic credential rotation
- ✅ AWS best practice
- ✅ No credential management needed

#### Disadvantages:
- ⚠️ Requires `network_mode: "host"` (less container isolation)

### Method 2: AWS Credentials File Mount

Mount AWS credentials file from the host to the container.

#### Implementation:

```yaml
# docker-compose.yml
version: '3.8'
services:
  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins-master
    volumes:
      - /var/jenkins_home:/var/jenkins_home
      - /home/ec2-user/.aws:/var/jenkins_home/.aws:ro
    environment:
      - AWS_DEFAULT_REGION=us-west-2
    user: "1000:1000"
```

#### User Data Script Addition:
```bash
# Create AWS credentials using instance metadata
mkdir -p /home/ec2-user/.aws

# Get temporary credentials from metadata service
ROLE_NAME=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
CREDENTIALS=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME)

# Extract credentials
ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.AccessKeyId')
SECRET_KEY=$(echo $CREDENTIALS | jq -r '.SecretAccessKey')
SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Token')

# Create credentials file
cat > /home/ec2-user/.aws/credentials << EOF
[default]
aws_access_key_id = $ACCESS_KEY
aws_secret_access_key = $SECRET_KEY
aws_session_token = $SESSION_TOKEN
EOF

cat > /home/ec2-user/.aws/config << EOF
[default]
region = ${aws_region}
EOF

# Set proper ownership
chown -R 1000:1000 /home/ec2-user/.aws
chmod 600 /home/ec2-user/.aws/credentials
```

#### Advantages:
- ✅ Standard Docker networking
- ✅ Works with existing AWS tooling

#### Disadvantages:
- ❌ Credentials become stale (need refresh mechanism)
- ❌ More complex credential management

### Method 3: Environment Variables (NOT RECOMMENDED)

Pass AWS credentials as environment variables.

#### Implementation:
```yaml
services:
  jenkins:
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}
      - AWS_DEFAULT_REGION=us-west-2
```

#### Why NOT recommended:
- ❌ Credentials visible in process list
- ❌ Credentials in Docker inspect output
- ❌ Security risk
- ❌ Credential rotation complexity

### Method 4: Custom Jenkins Docker Image with AWS CLI

Create a custom Jenkins image with AWS CLI pre-installed and configured.

#### Dockerfile:
```dockerfile
FROM jenkins/jenkins:lts

USER root

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws/

# Install additional tools
RUN apt-get update && apt-get install -y \
    jq \
    curl \
    && rm -rf /var/lib/apt/lists/*

USER jenkins

# Configure AWS to use EC2 instance metadata
RUN mkdir -p /var/jenkins_home/.aws
COPY aws-config /var/jenkins_home/.aws/config
```

#### AWS Config:
```ini
[default]
region = us-west-2
credential_source = Ec2InstanceMetadata
```

## Recommended Implementation

Here's the complete, production-ready implementation:

### Updated User Data Script:

```bash
#!/bin/bash

# Update system and install Docker
yum update -y
yum install -y docker jq
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install EFS utilities
yum install -y amazon-efs-utils

# Mount EFS
mkdir -p /mnt/efs /var/jenkins_home
echo "${efs_file_system_id}.efs.${aws_region}.amazonaws.com:/ /mnt/efs efs defaults,_netdev" >> /etc/fstab
mount -a

# Create Jenkins directories on EFS
mkdir -p /mnt/efs/jenkins_home /mnt/efs/build_cache
chown -R 1000:1000 /mnt/efs/jenkins_home /mnt/efs/build_cache

# Bind mount Jenkins home
echo "/mnt/efs/jenkins_home /var/jenkins_home none bind 0 0" >> /etc/fstab
mount -a

# Configure AWS credentials for Jenkins container
mkdir -p /home/ec2-user/.aws

# Method 1: Use EC2 Instance Metadata (Recommended)
cat > /home/ec2-user/.aws/config << EOF
[default]
region = ${aws_region}
credential_source = Ec2InstanceMetadata
output = json
EOF

# Set proper ownership
chown -R 1000:1000 /home/ec2-user/.aws

# Create optimized docker-compose.yml
cat > /home/ec2-user/docker-compose.yml << 'EOF'
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
      - /home/ec2-user/.aws:/var/jenkins_home/.aws:ro
    environment:
      - JENKINS_OPTS=--httpPort=8080
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false -Dhudson.model.DirectoryBrowserSupport.CSP=
      - AWS_DEFAULT_REGION=${aws_region}
      - AWS_REGION=${aws_region}
    user: "1000:1000"
    # Enable access to EC2 metadata service for IAM role credentials
    extra_hosts:
      - "host.docker.internal:host-gateway"
    # Alternative: use network_mode: "host" for direct metadata access
    # network_mode: "host"

networks:
  default:
    driver: bridge
EOF

# Start Jenkins
cd /home/ec2-user
docker-compose up -d

# Install AWS CLI v2 on host (for debugging)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# Wait for Jenkins to start
sleep 60

# Get initial admin password
if [ -f /var/jenkins_home/secrets/initialAdminPassword ]; then
    echo "Jenkins initial admin password:" > /home/ec2-user/jenkins-password.txt
    cat /var/jenkins_home/secrets/initialAdminPassword >> /home/ec2-user/jenkins-password.txt
    chown ec2-user:ec2-user /home/ec2-user/jenkins-password.txt
fi

echo "Jenkins installation completed with AWS IAM integration!"
```

## Testing IAM Access

### From Jenkins Container:

1. **Access Jenkins container:**
   ```bash
   docker exec -it jenkins-master bash
   ```

2. **Test AWS CLI:**
   ```bash
   aws sts get-caller-identity
   aws ecs list-clusters
   aws ecr get-login-token --region us-west-2
   ```

3. **Test from Jenkins Pipeline:**
   ```groovy
   pipeline {
       agent any
       stages {
           stage('Test AWS Access') {
               steps {
                   sh 'aws sts get-caller-identity'
                   sh 'aws ecs list-clusters'
               }
           }
       }
   }
   ```

## Troubleshooting

### Issue: "Unable to locate credentials"

**Solution 1: Check metadata service access**
```bash
# From inside container
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

**Solution 2: Verify AWS config**
```bash
# Check config file
cat /var/jenkins_home/.aws/config

# Test credentials
aws configure list
aws sts get-caller-identity
```

### Issue: "Network timeout accessing metadata service"

**Solution: Use host networking**
```yaml
services:
  jenkins:
    network_mode: "host"
```

### Issue: "Permission denied accessing AWS resources"

**Solution: Check IAM role permissions**
```bash
# Verify attached role
aws sts get-caller-identity

# Check role policies
aws iam list-attached-role-policies --role-name YourJenkinsRole
```

## Security Best Practices

1. **Use EC2 Instance Metadata Service v2 (IMDSv2):**
   ```bash
   # In user data
   yum install -y ec2-instance-connect
   echo 'export AWS_EC2_METADATA_SERVICE_ENDPOINT_MODE=IPv4' >> /etc/environment
   echo 'export AWS_EC2_METADATA_SERVICE_ENDPOINT=http://169.254.169.254' >> /etc/environment
   ```

2. **Limit IAM permissions to minimum required:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ecs:*",
           "ecr:GetAuthorizationToken",
           "ecr:BatchCheckLayerAvailability",
           "ecr:GetDownloadUrlForLayer",
           "ecr:BatchGetImage"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

3. **Use read-only mounts for credentials:**
   ```yaml
   volumes:
     - /home/ec2-user/.aws:/var/jenkins_home/.aws:ro
   ```

4. **Monitor credential usage:**
   ```bash
   # Enable CloudTrail for API call monitoring
   aws cloudtrail create-trail --name jenkins-audit-trail
   ```

This approach ensures secure, automatic credential management for your Jenkins Docker container while maintaining AWS best practices.