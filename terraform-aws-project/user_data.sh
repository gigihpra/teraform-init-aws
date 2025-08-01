#!/bin/bash

# EKS Node User Data Script
# This script is executed when EKS nodes are launched

# Variables passed from Terraform
CLUSTER_NAME="${cluster_name}"

# Set up the node to join the EKS cluster
/etc/eks/bootstrap.sh $CLUSTER_NAME

# Additional customizations can be added here
# For example:
# - Install additional software
# - Configure monitoring agents
# - Set up custom logging

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Install SSM agent (usually pre-installed on Amazon Linux 2)
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Install AWS CLI v2 (if not already installed)
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws/
fi

# Configure log rotation for containers
cat > /etc/logrotate.d/docker-containers << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 5
    daily
    compress
    size=10M
    missingok
    delaycompress
    copytruncate
}
EOF

# Ensure proper permissions
chmod 644 /etc/logrotate.d/docker-containers

# Log the completion
echo "EKS node initialization completed for cluster: $CLUSTER_NAME" >> /var/log/eks-node-init.log
