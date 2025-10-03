# Ansible Configuration for Todo API Deployment

This Ansible configuration automates the deployment of the Todo API application to production servers.

## Prerequisites

1. **Ansible Installation**: Install Ansible on your local machine
   ```bash
   pip install ansible
   ```

2. **Server Access**: Ensure you have SSH access to your target server
   - SSH key pair configured
   - Server IP address or hostname
   - User with sudo privileges

3. **Docker Hub Account**: For pulling application images
   - Docker Hub username and password/token

## Configuration

### 1. Update Inventory

Edit `inventory/hosts.yml` and replace the placeholder values:

```yaml
all:
  children:
    production:
      hosts:
        todo-api-server:
          ansible_host: "YOUR_SERVER_IP"
          ansible_user: ubuntu
          ansible_ssh_private_key_file: "~/.ssh/your_key.pem"
```

### 2. Configure Variables

Update `vars/main.yml` with your specific configuration:

- Docker Hub credentials (can be set via environment variables)
- Application settings
- Security configurations

### 3. Set Environment Variables

```bash
export DOCKER_HUB_USERNAME="your_username"
export DOCKER_HUB_PASSWORD="your_password_or_token"
```

## Usage

### Deploy Complete Application

```bash
# Run the complete deployment playbook
ansible-playbook -i inventory/hosts.yml site.yml

# Run with specific variables
ansible-playbook -i inventory/hosts.yml site.yml \
  -e server_ip=YOUR_SERVER_IP \
  -e ssh_key_path=~/.ssh/your_key.pem
```

### Run Specific Roles

```bash
# Only install Docker
ansible-playbook -i inventory/hosts.yml site.yml --tags docker

# Only deploy application
ansible-playbook -i inventory/hosts.yml site.yml --tags deploy

# Only security hardening
ansible-playbook -i inventory/hosts.yml site.yml --tags security
```

### Check Deployment Status

```bash
# Check if all services are running
ansible production -i inventory/hosts.yml -m shell -a "docker ps"

# Check application health
ansible production -i inventory/hosts.yml -m uri -a "url=http://localhost:3000/health"
```

## Roles Overview

### Common Role
- Installs basic system packages
- Sets up system configuration
- Creates application user

### Docker Role
- Installs Docker CE and Docker Compose
- Configures Docker service
- Adds users to docker group

### Security Role
- Configures UFW firewall
- Hardens SSH configuration
- Sets up fail2ban
- Enables automatic security updates

### Deploy Role
- Pulls Docker images from registry
- Deploys application using Docker Compose
- Creates systemd service
- Sets up management scripts and backups

## Management Scripts

After deployment, the following scripts are available on the server:

### Application Management
```bash
# On the server
cd /home/ubuntu/todo-api

# Start application
./manage-app.sh start

# Stop application
./manage-app.sh stop

# Restart application
./manage-app.sh restart

# Check status
./manage-app.sh status

# View logs
./manage-app.sh logs

# Update to latest version
./manage-app.sh update
```

### Database Backup
```bash
# Create backup
./backup-db.sh

# Create backup with custom name
./backup-db.sh my_backup_name
```

## Troubleshooting

### Connection Issues
```bash
# Test connection
ansible production -i inventory/hosts.yml -m ping

# Check SSH configuration
ssh -i ~/.ssh/your_key.pem ubuntu@YOUR_SERVER_IP
```

### Application Issues
```bash
# Check container status
ansible production -i inventory/hosts.yml -m shell -a "docker-compose -f /home/ubuntu/todo-api/docker-compose.yml ps"

# View application logs
ansible production -i inventory/hosts.yml -m shell -a "docker-compose -f /home/ubuntu/todo-api/docker-compose.yml logs"
```

### Firewall Issues
```bash
# Check UFW status
ansible production -i inventory/hosts.yml -m shell -a "ufw status"

# Check open ports
ansible production -i inventory/hosts.yml -m shell -a "netstat -tlnp"
```

## Security Considerations

- SSH keys are used for authentication (password auth disabled)
- UFW firewall is configured with minimal required ports
- Fail2ban protects against brute force attacks
- Automatic security updates are enabled
- Docker containers run with non-root users where possible

## Customization

To customize the deployment:

1. Modify variables in `vars/main.yml`
2. Update role tasks in `roles/*/tasks/main.yml`
3. Adjust templates in `roles/*/templates/`
4. Add additional roles as needed

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Ansible logs for detailed error messages
3. Verify server connectivity and permissions
4. Ensure all prerequisites are met