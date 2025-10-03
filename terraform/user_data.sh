#!/bin/bash

# User data script for Todo API server initialization
# This script runs on first boot to prepare the server

set -e

# Update system packages
apt-get update
apt-get upgrade -y

# Install essential packages
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Create application directory
mkdir -p /opt/todo-api
chown ubuntu:ubuntu /opt/todo-api

# Install Docker GPG key and repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index with Docker repository
apt-get update

# Install Docker
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install Docker Compose (standalone)
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create symbolic link for docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Configure firewall
ufw --force enable
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp

# Create log file for deployment tracking
touch /var/log/todo-api-deployment.log
chown ubuntu:ubuntu /var/log/todo-api-deployment.log

# Log completion
echo "$(date): Server initialization completed" >> /var/log/todo-api-deployment.log
echo "Project: ${project_name}" >> /var/log/todo-api-deployment.log
echo "Environment: ${environment}" >> /var/log/todo-api-deployment.log

# Reboot to ensure all changes take effect
reboot