# Minimal Jenkins inbound agent with AWS & Docker CLI
ARG DOCKER_DEFAULT_PLATFORM=linux/amd64
ARG JDK_VERSION=jdk21
ARG ALPINE_VERSION=3.22

FROM --platform=$DOCKER_DEFAULT_PLATFORM jenkins/inbound-agent:alpine${ALPINE_VERSION}-${JDK_VERSION}

USER root

# Keep image slim and reproducible
RUN apk update && apk add --no-cache \
    bash \
    ca-certificates \
    git \
    aws-cli \
    docker-cli \
    zip \
    unzip \
    openssh-client \
    && update-ca-certificates

# (Optional) create docker group so jenkins user can use docker socket if mounted
RUN addgroup -S docker && adduser jenkins docker

USER jenkins

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
