# Troubleshooting Guide

This comprehensive troubleshooting guide covers common issues you may encounter when deploying and running the Todo API, along with step-by-step solutions.

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Infrastructure Issues](#infrastructure-issues)
3. [Application Issues](#application-issues)
4. [Database Issues](#database-issues)
5. [Network and Connectivity Issues](#network-and-connectivity-issues)
6. [CI/CD Pipeline Issues](#cicd-pipeline-issues)
7. [Performance Issues](#performance-issues)
8. [Security Issues](#security-issues)
9. [Backup and Recovery Issues](#backup-and-recovery-issues)
10. [Monitoring and Logging Issues](#monitoring-and-logging-issues)

## Quick Diagnostics

### Health Check Commands

Run these commands first to get an overview of system status:

```bash
# Quick health check
./scripts/health-check.sh --host YOUR_SERVER_IP --verbose

# System status
./scripts/manage-environment.sh status --host YOUR_SERVER_IP

# Application logs
./scripts/manage-environment.sh logs --host YOUR_SERVER_IP
```

### Common Status Checks

```bash
# Check if server is accessible
ssh -o ConnectTimeout=10 ubuntu@YOUR_SERVER_IP exit

# Check Docker services
ssh ubuntu@YOUR_SERVER_IP "docker-compose -f /opt/todo-api/docker-compose.yml ps"

# Check system resources
ssh ubuntu@YOUR_SERVER_IP "df -h && free -h && uptime"

# Test API endpoints
curl -f http://YOUR_SERVER_IP:3000/health
curl -f http://YOUR_SERVER_IP:3000/todos
```

## Infrastructure Issues

### Issue: Terraform Provisioning Fails

#### Symptoms
- `terraform apply` command fails
- AWS resource creation errors
- Permission denied errors

#### Diagnosis
```bash
# Check AWS credentials
aws sts get-caller-identity

# Validate Terraform configuration
cd terraform
terraform validate

# Check Terraform state
terraform show
```

#### Solutions

**1. AWS Credentials Issues:**
```bash
# Reconfigure AWS CLI
aws configure

# Check IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name YOUR_USERNAME
```

**2. Resource Conflicts:**
```bash
# Check existing resources
aws ec2 describe-instances --filters "Name=tag:Project,Values=todo-api"
aws ec2 describe-security-groups --filters "Name=group-name,Values=*todo-api*"

# Clean up conflicting resources
terraform destroy --auto-approve
```

**3. Region/Availability Zone Issues:**
```bash
# Check available regions
aws ec2 describe-regions

# Update terraform variables
# Edit terraform/terraform.tfvars
aws_region = "us-west-2"  # Change to available region
```

### Issue: SSH Key Pair Problems

#### Symptoms
- Cannot SSH to server
- Key pair not found errors
- Permission denied (publickey)

#### Diagnosis
```bash
# Check key pair exists in AWS
aws ec2 describe-key-pairs --key-names YOUR_KEY_NAME

# Check local key file permissions
ls -la ~/.ssh/YOUR_KEY_NAME.pem
```

#### Solutions

**1. Create New Key Pair:**
```bash
# Create key pair in AWS
aws ec2 create-key-pair --key-name todo-api-new --query 'KeyMaterial' --output text > ~/.ssh/todo-api-new.pem
chmod 600 ~/.ssh/todo-api-new.pem

# Update Terraform configuration
# Edit terraform/terraform.tfvars
key_pair_name = "todo-api-new"
```

**2. Fix Key Permissions:**
```bash
chmod 600 ~/.ssh/YOUR_KEY_NAME.pem
```

**3. Test SSH Connection:**
```bash
ssh -vvv -i ~/.ssh/YOUR_KEY_NAME.pem ubuntu@YOUR_SERVER_IP
```

### Issue: Security Group Configuration

#### Symptoms
- Cannot access application on port 3000
- SSH connection refused
- Timeout errors

#### Diagnosis
```bash
# Check security group rules
aws ec2 describe-security-groups --group-names todo-api-production-sg

# Test port connectivity
telnet YOUR_SERVER_IP 22
telnet YOUR_SERVER_IP 3000
```

#### Solutions

**1. Update Security Group Rules:**
```bash
# Allow SSH from your IP
aws ec2 authorize-security-group-ingress \
  --group-name todo-api-production-sg \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32

# Allow HTTP traffic
aws ec2 authorize-security-group-ingress \
  --group-name todo-api-production-sg \
  --protocol tcp \
  --port 3000 \
  --cidr 0.0.0.0/0
```

**2. Re-apply Terraform Configuration:**
```bash
cd terraform
terraform plan
terraform apply
```

## Application Issues

### Issue: Application Won't Start

#### Symptoms
- Container exits immediately
- Health check fails
- No response on port 3000

#### Diagnosis
```bash
# Check container status
ssh ubuntu@YOUR_SERVER_IP "docker-compose -f /opt/todo-api/docker-compose.yml ps"

# Check application logs
ssh ubuntu@YOUR_SERVER_IP "docker-compose -f /opt/todo-api/docker-compose.yml logs todo-api"

# Check container configuration
ssh ubuntu@YOUR_SERVER_IP "docker-compose -f /opt/todo-api/docker-compose.yml config"
```

#### Solutions

**1. Environment Variable Issues:**
```bash
# Check environment variables
ssh ubuntu@YOUR_SERVER_IP "cat /opt/todo-api/.env"

# Update environment file
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
cat > /opt/todo-api/.env << 'ENVFILE'
NODE_ENV=production
PORT=3000
MONGODB_URI=mongodb://mongodb:27017/todoapp
ENVFILE
EOF

# Restart services
ssh ubuntu@YOUR_SERVER_IP "cd /opt/todo-api && docker-compose restart"
```

**2. Docker Image Issues:**
```bash
# Pull latest image
ssh ubuntu@YOUR_SERVER_IP "docker pull YOUR_DOCKERHUB_USER/todo-api:latest"

# Rebuild and restart
ssh ubuntu@YOUR_SERVER_IP "cd /opt/todo-api && docker-compose up -d --force-recreate"
```

**3. Port Binding Issues:**
```bash
# Check port usage
ssh ubuntu@YOUR_SERVER_IP "netstat -tlnp | grep :3000"

# Kill conflicting processes
ssh ubuntu@YOUR_SERVER_IP "sudo fuser -k 3000/tcp"

# Restart Docker service
ssh ubuntu@YOUR_SERVER_IP "sudo systemctl restart docker"
```

### Issue: Application Crashes Repeatedly

#### Symptoms
- Container keeps restarting
- Memory or CPU errors in logs
- Application becomes unresponsive

#### Diagnosis
```bash
# Check container restart count
ssh ubuntu@YOUR_SERVER_IP "docker ps -a | grep todo-api"

# Monitor resource usage
ssh ubuntu@YOUR_SERVER_IP "docker stats --no-stream"

# Check system resources
ssh ubuntu@YOUR_SERVER_IP "free -h && df -h"
```

#### Solutions

**1. Memory Issues:**
```bash
# Increase container memory limit
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
# Edit docker-compose.yml to add memory limits
sed -i '/todo-api:/a\    mem_limit: 512m' /opt/todo-api/docker-compose.yml
EOF

# Restart with new limits
ssh ubuntu@YOUR_SERVER_IP "cd /opt/todo-api && docker-compose up -d"
```

**2. CPU Issues:**
```bash
# Add CPU limits
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
# Edit docker-compose.yml
sed -i '/todo-api:/a\    cpus: "0.5"' /opt/todo-api/docker-compose.yml
EOF
```

**3. Disk Space Issues:**
```bash
# Clean up Docker resources
ssh ubuntu@YOUR_SERVER_IP "docker system prune -f"

# Clean up logs
ssh ubuntu@YOUR_SERVER_IP "sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log"
```

## Database Issues

### Issue: MongoDB Connection Failures

#### Symptoms
- "Connection refused" errors
- Database timeout errors
- Application can't connect to MongoDB

#### Diagnosis
```bash
# Check MongoDB container status
ssh ubuntu@YOUR_SERVER_IP "docker ps | grep mongodb"

# Check MongoDB logs
ssh ubuntu@YOUR_SERVER_IP "docker logs todo-api-mongodb-1"

# Test MongoDB connectivity
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongo --eval 'db.adminCommand(\"ismaster\")'"
```

#### Solutions

**1. MongoDB Container Issues:**
```bash
# Restart MongoDB container
ssh ubuntu@YOUR_SERVER_IP "docker restart todo-api-mongodb-1"

# Check MongoDB configuration
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 cat /etc/mongod.conf"

# Recreate MongoDB container
ssh ubuntu@YOUR_SERVER_IP "cd /opt/todo-api && docker-compose up -d --force-recreate mongodb"
```

**2. Network Connectivity Issues:**
```bash
# Check Docker network
ssh ubuntu@YOUR_SERVER_IP "docker network ls"
ssh ubuntu@YOUR_SERVER_IP "docker network inspect todo-api_default"

# Test network connectivity between containers
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-api-1 ping mongodb"
```

**3. Data Volume Issues:**
```bash
# Check volume mounts
ssh ubuntu@YOUR_SERVER_IP "docker volume ls"
ssh ubuntu@YOUR_SERVER_IP "docker volume inspect todo-api_mongodb_data"

# Fix volume permissions
ssh ubuntu@YOUR_SERVER_IP "sudo chown -R 999:999 /opt/todo-api/data/mongodb"
```

### Issue: Data Loss or Corruption

#### Symptoms
- Missing todo items
- Database errors
- Inconsistent data

#### Diagnosis
```bash
# Check database status
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongo todoapp --eval 'db.stats()'"

# Check collections
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongo todoapp --eval 'show collections'"

# Verify data integrity
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongo todoapp --eval 'db.todos.count()'"
```

#### Solutions

**1. Restore from Backup:**
```bash
# List available backups
./scripts/backup-restore.sh list --host YOUR_SERVER_IP

# Restore latest backup
./scripts/backup-restore.sh restore \
  --host YOUR_SERVER_IP \
  --name backup_YYYYMMDD_HHMMSS
```

**2. Repair Database:**
```bash
# Run MongoDB repair
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongo todoapp --eval 'db.repairDatabase()'"

# Check and fix collections
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongo todoapp --eval 'db.todos.validate()'"
```

## Network and Connectivity Issues

### Issue: Cannot Access Application Externally

#### Symptoms
- Timeout when accessing http://SERVER_IP:3000
- Connection refused errors
- Application works locally but not externally

#### Diagnosis
```bash
# Test local connectivity on server
ssh ubuntu@YOUR_SERVER_IP "curl -f http://localhost:3000/health"

# Check port binding
ssh ubuntu@YOUR_SERVER_IP "netstat -tlnp | grep :3000"

# Check firewall rules
ssh ubuntu@YOUR_SERVER_IP "sudo ufw status"
```

#### Solutions

**1. Firewall Configuration:**
```bash
# Allow port 3000 through firewall
ssh ubuntu@YOUR_SERVER_IP "sudo ufw allow 3000"

# Check firewall status
ssh ubuntu@YOUR_SERVER_IP "sudo ufw status numbered"
```

**2. Docker Port Binding:**
```bash
# Check Docker Compose port configuration
ssh ubuntu@YOUR_SERVER_IP "grep -A 5 'ports:' /opt/todo-api/docker-compose.yml"

# Fix port binding if needed
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
sed -i 's/- "3000"/- "3000:3000"/' /opt/todo-api/docker-compose.yml
cd /opt/todo-api && docker-compose up -d
EOF
```

**3. Security Group Rules:**
```bash
# Add security group rule for port 3000
aws ec2 authorize-security-group-ingress \
  --group-name todo-api-production-sg \
  --protocol tcp \
  --port 3000 \
  --cidr 0.0.0.0/0
```

### Issue: SSL/HTTPS Issues

#### Symptoms
- SSL certificate errors
- HTTPS not working
- Mixed content warnings

#### Diagnosis
```bash
# Check SSL certificate
./scripts/ssl-health-check.sh --domain YOUR_DOMAIN

# Check Nginx configuration
ssh ubuntu@YOUR_SERVER_IP "docker exec nginx-container nginx -t"

# Check certificate files
ssh ubuntu@YOUR_SERVER_IP "ls -la /opt/todo-api/ssl/"
```

#### Solutions

**1. Renew SSL Certificate:**
```bash
# Renew Let's Encrypt certificate
ssh ubuntu@YOUR_SERVER_IP "docker exec nginx-container certbot renew"

# Restart Nginx
ssh ubuntu@YOUR_SERVER_IP "docker restart nginx-container"
```

**2. Fix Nginx Configuration:**
```bash
# Check Nginx logs
ssh ubuntu@YOUR_SERVER_IP "docker logs nginx-container"

# Reload Nginx configuration
ssh ubuntu@YOUR_SERVER_IP "docker exec nginx-container nginx -s reload"
```

## CI/CD Pipeline Issues

### Issue: GitHub Actions Deployment Fails

#### Symptoms
- Deployment job fails in GitHub Actions
- SSH connection errors in pipeline
- Docker push failures

#### Diagnosis
```bash
# Check GitHub Actions logs in repository
# Go to Actions tab → Select failed workflow → Check job logs

# Verify secrets are configured
# Go to Settings → Secrets and variables → Actions
```

#### Solutions

**1. SSH Connection Issues:**
```bash
# Verify SSH private key format in GitHub secrets
# Key should start with -----BEGIN OPENSSH PRIVATE KEY-----

# Test SSH key locally
ssh -i ~/.ssh/YOUR_KEY ubuntu@YOUR_SERVER_IP exit

# Update SSH_PRIVATE_KEY secret with correct format
```

**2. Docker Hub Authentication:**
```bash
# Test Docker Hub login locally
docker login -u YOUR_DOCKERHUB_USER -p YOUR_DOCKERHUB_TOKEN

# Update DOCKER_USERNAME and DOCKER_PASSWORD secrets
# Use access token instead of password for better security
```

**3. Ansible Playbook Issues:**
```bash
# Test Ansible playbook locally
ansible-playbook -i 'YOUR_SERVER_IP,' ansible/site.yml --check

# Check playbook syntax
ansible-playbook ansible/site.yml --syntax-check
```

### Issue: Build Failures

#### Symptoms
- Docker build fails
- Test failures in CI
- Dependency installation errors

#### Diagnosis
```bash
# Test build locally
docker build -t todo-api:test .

# Run tests locally
npm test

# Check package.json dependencies
npm audit
```

#### Solutions

**1. Docker Build Issues:**
```bash
# Clear Docker build cache
docker builder prune -f

# Build with no cache
docker build --no-cache -t todo-api:test .

# Check Dockerfile syntax
docker build --dry-run -t todo-api:test .
```

**2. Test Failures:**
```bash
# Run tests with verbose output
npm test -- --verbose

# Check test environment
NODE_ENV=test npm test

# Update test dependencies
npm update --save-dev
```

## Performance Issues

### Issue: Slow Response Times

#### Symptoms
- API responses take > 5 seconds
- Timeout errors
- High CPU/memory usage

#### Diagnosis
```bash
# Check response times
./scripts/health-check.sh --host YOUR_SERVER_IP --verbose

# Monitor system resources
ssh ubuntu@YOUR_SERVER_IP "top -n 1"
ssh ubuntu@YOUR_SERVER_IP "docker stats --no-stream"

# Check database performance
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongo todoapp --eval 'db.todos.explain().find()'"
```

#### Solutions

**1. Database Optimization:**
```bash
# Add database indexes
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
docker exec todo-api-mongodb-1 mongo todoapp --eval '
db.todos.createIndex({createdAt: -1});
db.todos.createIndex({completed: 1});
'
EOF
```

**2. Resource Scaling:**
```bash
# Upgrade instance type
cd terraform
# Edit terraform.tfvars
instance_type = "t3.medium"  # Upgrade from t3.micro

terraform plan
terraform apply
```

**3. Application Optimization:**
```bash
# Enable connection pooling
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
cat >> /opt/todo-api/.env << 'ENVFILE'
DB_MAX_POOL_SIZE=10
DB_MIN_POOL_SIZE=2
ENVFILE
EOF

# Restart application
ssh ubuntu@YOUR_SERVER_IP "cd /opt/todo-api && docker-compose restart todo-api"
```

### Issue: High Memory Usage

#### Symptoms
- Out of memory errors
- Container killed by OOM killer
- System becomes unresponsive

#### Diagnosis
```bash
# Check memory usage
ssh ubuntu@YOUR_SERVER_IP "free -h"
ssh ubuntu@YOUR_SERVER_IP "docker stats --no-stream"

# Check for memory leaks
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-api-1 node --expose-gc -e 'console.log(process.memoryUsage())'"
```

#### Solutions

**1. Add Memory Limits:**
```bash
# Set container memory limits
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
cat >> /opt/todo-api/docker-compose.yml << 'COMPOSE'
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
COMPOSE
EOF

# Restart with new limits
ssh ubuntu@YOUR_SERVER_IP "cd /opt/todo-api && docker-compose up -d"
```

**2. Enable Swap:**
```bash
# Add swap space
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
EOF
```

## Security Issues

### Issue: Unauthorized Access

#### Symptoms
- Unexpected API calls
- Security warnings
- Suspicious log entries

#### Diagnosis
```bash
# Check access logs
ssh ubuntu@YOUR_SERVER_IP "docker logs todo-api-api-1 | grep -E '(POST|PUT|DELETE)'"

# Check failed authentication attempts
ssh ubuntu@YOUR_SERVER_IP "sudo grep 'Failed password' /var/log/auth.log"

# Check firewall logs
ssh ubuntu@YOUR_SERVER_IP "sudo grep 'UFW BLOCK' /var/log/ufw.log"
```

#### Solutions

**1. Strengthen Firewall:**
```bash
# Restrict SSH access to specific IPs
ssh ubuntu@YOUR_SERVER_IP "sudo ufw delete allow 22"
ssh ubuntu@YOUR_SERVER_IP "sudo ufw allow from YOUR_IP to any port 22"

# Add rate limiting
ssh ubuntu@YOUR_SERVER_IP "sudo ufw limit ssh"
```

**2. Update Security Groups:**
```bash
# Restrict access to known IPs
aws ec2 revoke-security-group-ingress \
  --group-name todo-api-production-sg \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-name todo-api-production-sg \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32
```

**3. Enable Additional Security:**
```bash
# Install fail2ban
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
sudo apt update
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
EOF
```

## Backup and Recovery Issues

### Issue: Backup Creation Fails

#### Symptoms
- Backup script errors
- No backup files created
- MongoDB dump failures

#### Diagnosis
```bash
# Test backup manually
./scripts/backup-restore.sh backup --host YOUR_SERVER_IP --name test_backup

# Check backup directory
ssh ubuntu@YOUR_SERVER_IP "ls -la /opt/todo-api/backups/"

# Check MongoDB container
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongodump --help"
```

#### Solutions

**1. Fix Backup Directory Permissions:**
```bash
# Create backup directory with correct permissions
ssh ubuntu@YOUR_SERVER_IP "sudo mkdir -p /opt/todo-api/backups"
ssh ubuntu@YOUR_SERVER_IP "sudo chown ubuntu:ubuntu /opt/todo-api/backups"
```

**2. Fix MongoDB Access:**
```bash
# Test MongoDB connectivity
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongo --eval 'db.adminCommand(\"ismaster\")'"

# Restart MongoDB if needed
ssh ubuntu@YOUR_SERVER_IP "docker restart todo-api-mongodb-1"
```

### Issue: Backup Restore Fails

#### Symptoms
- Restore script errors
- Data not restored
- Database corruption after restore

#### Diagnosis
```bash
# Check backup file integrity
ssh ubuntu@YOUR_SERVER_IP "tar -tzf /opt/todo-api/backups/BACKUP_NAME.tar.gz"

# Test restore process
./scripts/backup-restore.sh restore --host YOUR_SERVER_IP --name BACKUP_NAME
```

#### Solutions

**1. Verify Backup Integrity:**
```bash
# Extract and verify backup
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
cd /opt/todo-api/backups
tar -xzf BACKUP_NAME.tar.gz
ls -la BACKUP_NAME/
EOF
```

**2. Manual Restore Process:**
```bash
# Stop application
ssh ubuntu@YOUR_SERVER_IP "cd /opt/todo-api && docker-compose stop todo-api"

# Drop existing database
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongo todoapp --eval 'db.dropDatabase()'"

# Restore manually
ssh ubuntu@YOUR_SERVER_IP "docker exec todo-api-mongodb-1 mongorestore --db todoapp /path/to/backup"

# Start application
ssh ubuntu@YOUR_SERVER_IP "cd /opt/todo-api && docker-compose start todo-api"
```

## Monitoring and Logging Issues

### Issue: Missing or Incomplete Logs

#### Symptoms
- No application logs
- Log files not rotating
- Missing error information

#### Diagnosis
```bash
# Check log files
ssh ubuntu@YOUR_SERVER_IP "ls -la /opt/todo-api/logs/"

# Check Docker logging
ssh ubuntu@YOUR_SERVER_IP "docker logs todo-api-api-1"

# Check system logs
ssh ubuntu@YOUR_SERVER_IP "sudo journalctl -u docker"
```

#### Solutions

**1. Configure Log Rotation:**
```bash
# Set up logrotate
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
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

**2. Fix Docker Logging:**
```bash
# Configure Docker logging in compose file
ssh ubuntu@YOUR_SERVER_IP << 'EOF'
cat >> /opt/todo-api/docker-compose.yml << 'LOGGING'
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
LOGGING
EOF
```

## Emergency Recovery Procedures

### Complete System Recovery

If the system is completely unresponsive:

```bash
# 1. Provision new infrastructure
./scripts/provision-infrastructure.sh --key-pair todo-api-emergency --environment production

# 2. Configure new server
ansible-playbook -i 'NEW_SERVER_IP,' ansible/site.yml

# 3. Restore latest backup
./scripts/backup-restore.sh restore --host NEW_SERVER_IP --name latest_backup

# 4. Deploy application
./scripts/deploy.sh --host NEW_SERVER_IP --tag your-dockerhub-user/todo-api:latest

# 5. Update DNS/load balancer to point to new server
```

### Data Recovery from Snapshots

If using AWS EBS snapshots:

```bash
# 1. Find latest snapshot
aws ec2 describe-snapshots --owner-ids self --filters "Name=tag:Project,Values=todo-api"

# 2. Create volume from snapshot
aws ec2 create-volume --snapshot-id snap-12345678 --availability-zone us-east-1a

# 3. Attach volume to new instance
aws ec2 attach-volume --volume-id vol-12345678 --instance-id i-12345678 --device /dev/sdf

# 4. Mount and recover data
ssh ubuntu@NEW_SERVER_IP << 'EOF'
sudo mkdir /mnt/recovery
sudo mount /dev/xvdf /mnt/recovery
sudo cp -r /mnt/recovery/data/* /opt/todo-api/data/
sudo chown -R ubuntu:ubuntu /opt/todo-api/data/
EOF
```

Remember to always test your recovery procedures in a staging environment before applying them to production!