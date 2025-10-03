# Complete Deployment Guide

This comprehensive guide covers all aspects of deploying the Todo API from development to production, including infrastructure provisioning, configuration management, and ongoing maintenance.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Infrastructure Provisioning](#infrastructure-provisioning)
3. [Server Configuration](#server-configuration)
4. [Application Deployment](#application-deployment)
5. [SSL and Domain Setup](#ssl-and-domain-setup)
6. [CI/CD Pipeline Setup](#cicd-pipeline-setup)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)
8. [Backup and Recovery](#backup-and-recovery)
9. [Scaling and Optimization](#scaling-and-optimization)
10. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools and Accounts

#### Local Development Machine
- **Docker** (20.10+) and **Docker Compose** (2.0+)
- **Node.js** (18+) and **npm**
- **Git** for version control
- **AWS CLI** (2.0+) configured with credentials
- **Terraform** (1.0+) for infrastructure provisioning
- **Ansible** (2.9+) for configuration management
- **SSH client** for server access

#### Cloud Services
- **AWS Account** with appropriate permissions:
  - EC2 (create instances, security groups, EIPs)
  - IAM (create roles and policies)
  - CloudWatch (create log groups)
- **Docker Hub Account** for container registry
- **Domain Name** (optional, for custom domain)

#### GitHub Repository
- Repository with admin access for secrets configuration
- GitHub Actions enabled

### AWS Permissions

Your AWS user/role needs these permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "iam:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Infrastructure Provisioning

### Step 1: Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure
# Enter: Access Key ID, Secret Access Key, Region (e.g., us-east-1), Output format (json)

# Verify configuration
aws sts get-caller-identity
```

### Step 2: Create SSH Key Pair

```bash
# Option 1: Create key pair via AWS CLI
aws ec2 create-key-pair \
  --key-name todo-api-prod \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/todo-api-prod.pem

chmod 600 ~/.ssh/todo-api-prod.pem

# Option 2: Use existing key pair
# Ensure your public key is uploaded to AWS EC2 Key Pairs
```

### Step 3: Provision Infrastructure with Terraform

```bash
# Navigate to project root
cd /path/to/todo-api

# Provision infrastructure
./scripts/provision-infrastructure.sh \
  --key-pair todo-api-prod \
  --environment production \
  --region us-east-1 \
  --type t3.small \
  --project todo-api

# For staging environment
./scripts/provision-infrastructure.sh \
  --key-pair todo-api-staging \
  --environment staging \
  --region us-east-1 \
  --type t3.micro \
  --project todo-api
```

**Expected Output:**
```
[INFO] Infrastructure provisioned successfully!
[INFO] Server is ready at: 54.123.45.67
[INFO] SSH command: ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67
```

### Step 4: Verify Infrastructure

```bash
# Test SSH connectivity
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 exit

# Check server status
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "uptime && df -h"
```

## Server Configuration

### Step 1: Configure Ansible Inventory

Create or update the inventory file:

```bash
# Create inventory file
cat > inventory/production << EOF
[production]
54.123.45.67 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/todo-api-prod.pem

[production:vars]
app_env=production
docker_image_tag=your-dockerhub-user/todo-api:latest
EOF
```

### Step 2: Run Ansible Configuration

```bash
# Run full configuration playbook
ansible-playbook -i inventory/production ansible/site.yml

# Run specific roles only
ansible-playbook -i inventory/production ansible/site.yml --tags docker,security

# Dry run to check what will be changed
ansible-playbook -i inventory/production ansible/site.yml --check
```

**What Ansible Configures:**
- System updates and security patches
- Docker and Docker Compose installation
- Firewall configuration (UFW)
- SSH hardening
- Application directory structure
- Docker Compose service files
- Backup scripts

### Step 3: Verify Server Configuration

```bash
# Check Docker installation
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "docker --version && docker-compose --version"

# Check firewall status
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "sudo ufw status"

# Verify application directory
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "ls -la /opt/todo-api/"
```

## Application Deployment

### Step 1: Build and Push Docker Images

```bash
# Build Docker image
docker build -t your-dockerhub-user/todo-api:v1.0.0 .
docker build -t your-dockerhub-user/todo-api:latest .

# Push to Docker Hub
docker login
docker push your-dockerhub-user/todo-api:v1.0.0
docker push your-dockerhub-user/todo-api:latest
```

### Step 2: Deploy Application

```bash
# Deploy using deployment script
./scripts/deploy.sh \
  --host 54.123.45.67 \
  --tag your-dockerhub-user/todo-api:v1.0.0 \
  --user ubuntu

# Deploy latest version
./scripts/deploy.sh \
  --host 54.123.45.67 \
  --tag your-dockerhub-user/todo-api:latest \
  --user ubuntu
```

### Step 3: Verify Deployment

```bash
# Run comprehensive health check
./scripts/health-check.sh \
  --host 54.123.45.67 \
  --port 3000 \
  --verbose

# Test API endpoints
curl http://54.123.45.67:3000/health
curl http://54.123.45.67:3000/todos

# Check application logs
./scripts/manage-environment.sh logs --host 54.123.45.67
```

## SSL and Domain Setup

### Step 1: Configure Domain (Optional)

If you have a domain name:

```bash
# Point your domain to the server IP
# Create A record: api.yourdomain.com -> 54.123.45.67
```

### Step 2: Set up Nginx Reverse Proxy with SSL

```bash
# Deploy Nginx configuration
ansible-playbook -i inventory/production ansible/site.yml --tags nginx

# Set up SSL certificates
./scripts/ssl-manager.sh \
  --domain api.yourdomain.com \
  --email your-email@domain.com \
  --host 54.123.45.67
```

### Step 3: Verify SSL Setup

```bash
# Test HTTPS access
curl https://api.yourdomain.com/health

# Check SSL certificate
./scripts/ssl-health-check.sh --domain api.yourdomain.com
```

## CI/CD Pipeline Setup

### Step 1: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

```
DOCKER_USERNAME=your-dockerhub-username
DOCKER_PASSWORD=your-dockerhub-password-or-token
SERVER_HOST=54.123.45.67
SERVER_USER=ubuntu
SSH_PRIVATE_KEY=<contents-of-your-private-key-file>
```

### Step 2: Test CI/CD Pipeline

```bash
# Make a small change and push to main branch
echo "# Test deployment" >> README.md
git add README.md
git commit -m "Test CI/CD pipeline"
git push origin main
```

### Step 3: Monitor Pipeline Execution

1. Go to GitHub Actions tab in your repository
2. Watch the workflow execution
3. Check each job's logs for any issues
4. Verify successful deployment

## Monitoring and Maintenance

### Health Monitoring

```bash
# Set up automated health checks (cron job)
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 << 'EOF'
(crontab -l 2>/dev/null; echo "*/5 * * * * curl -f http://localhost:3000/health || echo 'Health check failed' | logger") | crontab -
EOF

# Manual health check
./scripts/health-check.sh --host 54.123.45.67 --verbose
```

### Log Management

```bash
# View application logs
./scripts/manage-environment.sh logs --host 54.123.45.67

# Set up log rotation
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 << 'EOF'
sudo tee /etc/logrotate.d/todo-api << 'LOGROTATE'
/opt/todo-api/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 ubuntu ubuntu
}
LOGROTATE
EOF
```

### Resource Monitoring

```bash
# Check system resources
./scripts/manage-environment.sh status --host 54.123.45.67

# Set up CloudWatch monitoring (if configured)
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/todo-api"
```

## Backup and Recovery

### Automated Backup Setup

```bash
# Set up automated daily backups
./scripts/backup-restore.sh schedule \
  --host 54.123.45.67 \
  --retention 7

# Verify backup schedule
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "crontab -l | grep backup"
```

### Manual Backup Operations

```bash
# Create manual backup
./scripts/backup-restore.sh backup \
  --host 54.123.45.67 \
  --name manual_backup_$(date +%Y%m%d)

# List available backups
./scripts/backup-restore.sh list --host 54.123.45.67

# Restore from backup
./scripts/backup-restore.sh restore \
  --host 54.123.45.67 \
  --name backup_20241003_120000
```

### Disaster Recovery Plan

1. **Infrastructure Recovery:**
   ```bash
   # Re-provision infrastructure
   ./scripts/provision-infrastructure.sh --key-pair todo-api-prod --environment production
   
   # Re-configure server
   ansible-playbook -i inventory/production ansible/site.yml
   ```

2. **Data Recovery:**
   ```bash
   # Restore latest backup
   ./scripts/backup-restore.sh restore --host NEW_SERVER_IP --name latest_backup
   
   # Redeploy application
   ./scripts/deploy.sh --host NEW_SERVER_IP --tag your-dockerhub-user/todo-api:latest
   ```

## Scaling and Optimization

### Vertical Scaling (Upgrade Instance)

```bash
# Update Terraform configuration
cd terraform
# Edit variables.tf to change instance_type

# Apply changes
terraform plan
terraform apply

# Restart services after resize
./scripts/manage-environment.sh restart --host 54.123.45.67
```

### Horizontal Scaling (Load Balancer)

For high-traffic scenarios, consider:

1. **Application Load Balancer (ALB)**
2. **Multiple EC2 instances**
3. **Shared database (RDS)**
4. **Container orchestration (ECS/EKS)**

### Performance Optimization

```bash
# Optimize Docker images
docker build --target production -t your-dockerhub-user/todo-api:optimized .

# Configure resource limits
# Edit docker-compose.prod.yml to add resource constraints

# Monitor performance
./scripts/manage-environment.sh status --host 54.123.45.67
```

## Troubleshooting

### Common Deployment Issues

#### 1. SSH Connection Failures
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/todo-api-prod.pem

# Test SSH connectivity
ssh -vvv -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67

# Check security group rules
aws ec2 describe-security-groups --group-names todo-api-production-sg
```

#### 2. Docker Issues
```bash
# Check Docker service status
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "sudo systemctl status docker"

# Restart Docker service
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "sudo systemctl restart docker"

# Check Docker Compose
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "cd /opt/todo-api && docker-compose ps"
```

#### 3. Application Startup Issues
```bash
# Check application logs
./scripts/manage-environment.sh logs --host 54.123.45.67

# Check environment variables
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "cd /opt/todo-api && docker-compose config"

# Restart application
./scripts/manage-environment.sh restart --host 54.123.45.67
```

#### 4. Database Connection Issues
```bash
# Check MongoDB container
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "docker logs todo-api-mongodb-1"

# Test database connectivity
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "docker exec todo-api-mongodb-1 mongo --eval 'db.adminCommand(\"ismaster\")'"

# Check network connectivity
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "docker network ls && docker network inspect todo-api_default"
```

### Performance Issues

```bash
# Check system resources
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "top -n 1 && free -h && df -h"

# Monitor container resources
ssh -i ~/.ssh/todo-api-prod.pem ubuntu@54.123.45.67 "docker stats --no-stream"

# Check application response times
./scripts/health-check.sh --host 54.123.45.67 --verbose
```

### Recovery Procedures

#### Application Recovery
```bash
# Rollback to previous version
./scripts/rollback.sh \
  --host 54.123.45.67 \
  --docker-user your-dockerhub-user

# Force restart all services
./scripts/manage-environment.sh restart --host 54.123.45.67

# Clean up and redeploy
./scripts/manage-environment.sh cleanup --host 54.123.45.67
./scripts/deploy.sh --host 54.123.45.67 --tag your-dockerhub-user/todo-api:latest
```

#### Infrastructure Recovery
```bash
# Destroy and recreate infrastructure
cd terraform
terraform destroy --auto-approve
terraform apply --auto-approve

# Reconfigure server
ansible-playbook -i inventory/production ansible/site.yml

# Restore data and redeploy
./scripts/backup-restore.sh restore --host NEW_IP --name latest_backup
./scripts/deploy.sh --host NEW_IP --tag your-dockerhub-user/todo-api:latest
```

## Best Practices

### Security
- Regularly update system packages
- Use dedicated SSH keys for deployment
- Implement proper firewall rules
- Enable SSL/TLS for all communications
- Regularly rotate credentials and keys

### Monitoring
- Set up automated health checks
- Monitor system resources
- Implement log aggregation
- Set up alerting for critical issues
- Regular backup verification

### Deployment
- Always test in staging first
- Use blue-green deployment for zero downtime
- Maintain rollback capability
- Document all changes
- Automate as much as possible

### Maintenance
- Regular security updates
- Database maintenance and optimization
- Log rotation and cleanup
- Backup testing and verification
- Performance monitoring and optimization

This guide provides a comprehensive approach to deploying and maintaining the Todo API in production. Follow these procedures carefully and adapt them to your specific requirements and constraints.