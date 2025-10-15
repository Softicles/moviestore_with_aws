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