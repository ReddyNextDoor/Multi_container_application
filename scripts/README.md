# Deployment Scripts

This directory contains scripts for managing the Todo API deployment, health checks, rollbacks, and notifications.

## Scripts Overview

### 1. deploy.sh
**Purpose:** Main deployment script used by CI/CD pipeline and manual deployments.

**Usage:**
```bash
./scripts/deploy.sh --host 192.168.1.100 --tag myuser/todo-api:v1.0.0
./scripts/deploy.sh -h example.com -u deploy -t myuser/todo-api:latest -e staging
```

**Features:**
- Validates SSH connectivity
- Checks Ansible playbook syntax
- Deploys using Ansible with dynamic image tags
- Performs post-deployment health checks
- Provides detailed deployment summary

### 2. rollback.sh
**Purpose:** Rollback to previous application version in case of deployment issues.

**Usage:**
```bash
# Automatic rollback to previous version
./scripts/rollback.sh --host 192.168.1.100 --docker-user myuser

# Rollback to specific version
./scripts/rollback.sh -h example.com -d myuser -t v1.0.0

# List available versions
./scripts/rollback.sh --list-tags --docker-user myuser
```

**Features:**
- Automatic detection of previous version
- Manual version selection
- Lists available Docker Hub tags
- Confirmation prompts for safety
- Post-rollback health verification

### 3. health-check.sh
**Purpose:** Comprehensive health checks for the deployed application.

**Usage:**
```bash
# Check local deployment
./scripts/health-check.sh

# Check remote deployment
./scripts/health-check.sh --host 192.168.1.100 --port 3000

# Verbose output with detailed debugging
./scripts/health-check.sh -h example.com -p 80 -v
```

**Features:**
- Basic connectivity tests
- Health endpoint verification
- Database connectivity checks
- API endpoint testing (CRUD operations)
- Response time measurements
- Detailed reporting with color-coded results

### 4. notify.sh
**Purpose:** Send deployment notifications through various channels.

**Usage:**
```bash
# Console notification
./scripts/notify.sh --type console --status success --version v1.0.0

# Slack notification
SLACK_WEBHOOK_URL="https://hooks.slack.com/..." \
./scripts/notify.sh -t slack -s success -v v1.0.0

# Discord notification
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..." \
./scripts/notify.sh -t discord -s failure -v main-abc123
```

**Features:**
- Multiple notification channels (Console, Slack, Discord, Email)
- Status-based formatting and colors
- Deployment metadata inclusion
- Webhook integration support

## Environment Variables

### Common Variables
```bash
SERVER_HOST=192.168.1.100          # Target server
SERVER_USER=ubuntu                 # SSH username
DOCKER_USERNAME=myuser             # Docker Hub username
APP_NAME=todo-api                  # Application name
```

### CI/CD Integration Variables
```bash
DOCKER_IMAGE_TAG=myuser/todo-api:v1.0.0  # Full image tag
APP_ENV=production                        # Environment name
SSH_PRIVATE_KEY="-----BEGIN..."          # SSH private key
```

### Notification Variables
```bash
# Slack
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
SLACK_CHANNEL=#deployments

# Discord
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...

# Email
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=user@example.com
SMTP_PASSWORD=password
EMAIL_FROM=deployments@example.com
EMAIL_TO=team@example.com
```

## Integration with CI/CD

These scripts are designed to work seamlessly with the GitHub Actions CI/CD pipeline:

### In GitHub Actions Workflow
```yaml
- name: Deploy with custom script
  run: |
    ./scripts/deploy.sh \
      --host ${{ secrets.SERVER_HOST }} \
      --tag ${{ needs.build-docker.outputs.image-tag }}

- name: Health check
  run: |
    ./scripts/health-check.sh \
      --host ${{ secrets.SERVER_HOST }} \
      --timeout 60

- name: Notify deployment status
  if: always()
  run: |
    ./scripts/notify.sh \
      --type slack \
      --status ${{ job.status }} \
      --version ${{ github.sha }}
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Dependencies

### Required Tools
- `curl` - HTTP requests and API calls
- `ssh` - Remote server access
- `ansible-playbook` - Configuration management
- `jq` - JSON parsing (recommended)

### Installation
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install curl ssh ansible jq

# macOS
brew install curl openssh ansible jq

# CentOS/RHEL
sudo yum install curl openssh ansible jq
```

## Security Considerations

1. **SSH Keys:** Use dedicated deployment keys, rotate regularly
2. **Secrets:** Never commit secrets to repository
3. **Webhooks:** Validate webhook URLs and use HTTPS
4. **Permissions:** Run scripts with minimal required permissions
5. **Logging:** Avoid logging sensitive information

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   ```bash
   # Test SSH connectivity
   ssh -o ConnectTimeout=10 user@server exit
   
   # Check SSH key permissions
   chmod 600 ~/.ssh/deploy_key
   ```

2. **Ansible Playbook Errors**
   ```bash
   # Validate playbook syntax
   ansible-playbook ansible/site.yml --syntax-check
   
   # Run in check mode
   ansible-playbook -i inventory ansible/site.yml --check
   ```

3. **Health Check Failures**
   ```bash
   # Check application logs
   docker-compose -f /path/to/docker-compose.yml logs
   
   # Verify service status
   docker-compose -f /path/to/docker-compose.yml ps
   ```

4. **Notification Failures**
   ```bash
   # Test webhook URLs
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test"}' $WEBHOOK_URL
   ```

### Debug Mode

Enable verbose output for debugging:
```bash
# Set debug environment
export VERBOSE=true

# Run scripts with verbose output
./scripts/health-check.sh -v
./scripts/deploy.sh --host server --tag image:tag
```

## Best Practices

1. **Testing:** Always test scripts in staging environment first
2. **Backups:** Ensure database backups before deployments
3. **Monitoring:** Set up monitoring and alerting for deployments
4. **Documentation:** Keep deployment logs and documentation updated
5. **Rollback Plan:** Always have a rollback strategy ready

## Contributing

When modifying these scripts:

1. Test thoroughly in development environment
2. Follow shell scripting best practices
3. Add appropriate error handling
4. Update documentation
5. Maintain backward compatibility where possible

## Support

For issues with these scripts:

1. Check the troubleshooting section above
2. Review script logs and error messages
3. Verify environment variables and dependencies
4. Test individual components (SSH, Ansible, Docker, etc.)
5. Consult the main project documentation