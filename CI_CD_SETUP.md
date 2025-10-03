# CI/CD Pipeline Setup Guide

This document explains how to set up and configure the GitHub Actions CI/CD pipeline for the Todo API deployment.

## Overview

The CI/CD pipeline automatically:
1. Builds and tests the application on every push/PR
2. Builds and pushes Docker images to Docker Hub (main branch only)
3. Deploys to production server using Ansible (main branch only)
4. Performs health checks and rollback on failure
5. Sends deployment notifications

## Required Secrets

Configure these secrets in your GitHub repository settings (Settings > Secrets and variables > Actions):

### Docker Hub Configuration
- `DOCKER_USERNAME`: Your Docker Hub username
- `DOCKER_PASSWORD`: Your Docker Hub password or access token

### Server Configuration
- `SERVER_HOST`: IP address or hostname of your production server
- `SERVER_USER`: SSH username for the production server (e.g., 'ubuntu', 'root')
- `SSH_PRIVATE_KEY`: Private SSH key for accessing the production server

## Setup Steps

### 1. Docker Hub Setup
1. Create a Docker Hub account if you don't have one
2. Create a new repository named `todo-api`
3. Generate an access token (Account Settings > Security > New Access Token)
4. Add the username and token to GitHub secrets

### 2. Server Setup
1. Ensure your production server is provisioned with Terraform
2. Ensure Ansible has configured the server with Docker
3. Generate SSH key pair if not already done:
   ```bash
   ssh-keygen -t rsa -b 4096 -C "github-actions"
   ```
4. Add the public key to your server's `~/.ssh/authorized_keys`
5. Add the private key to GitHub secrets as `SSH_PRIVATE_KEY`

### 3. Ansible Playbook Updates
The pipeline expects your Ansible playbook to accept these variables:
- `docker_image_tag`: The Docker image tag to deploy
- `app_env`: Environment name (production)

Update your `ansible/site.yml` to use these variables for deployment.

## Pipeline Workflow

### Build and Test Job
- Runs on every push and pull request
- Sets up Node.js environment
- Installs dependencies with `npm ci`
- Runs linting (if configured)
- Executes tests with MongoDB service
- Generates test coverage

### Docker Build Job
- Runs only on main branch pushes
- Builds Docker image using Buildx
- Tags with branch name, SHA, and 'latest'
- Pushes to Docker Hub registry
- Uses GitHub Actions cache for faster builds

### Deploy Job
- Runs only on main branch pushes after successful build
- Sets up SSH access to production server
- Installs Ansible
- Runs deployment playbook with new image tag
- Performs health check on deployed application
- Initiates rollback on failure

### Notification Job
- Runs after all other jobs complete
- Reports deployment status
- Provides deployment details

## Health Check Endpoint

Ensure your application has a `/health` endpoint that returns HTTP 200 when healthy:

```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString() 
  });
});
```

## Rollback Strategy

The pipeline automatically attempts rollback on deployment failure by:
1. Fetching the previous successful image tag from Docker Hub
2. Re-running the Ansible playbook with the previous tag
3. This requires maintaining image history in Docker Hub

## Monitoring and Debugging

### View Pipeline Status
- Go to your repository's "Actions" tab
- Click on any workflow run to see detailed logs
- Each job shows individual step results

### Common Issues
1. **SSH Connection Failed**: Check SSH key format and server access
2. **Docker Push Failed**: Verify Docker Hub credentials
3. **Health Check Failed**: Ensure application starts correctly and `/health` endpoint works
4. **Ansible Deployment Failed**: Check playbook syntax and server configuration

### Debug Commands
```bash
# Test SSH connection locally
ssh -i ~/.ssh/your-key user@server-ip

# Test Docker Hub login
docker login

# Test Ansible playbook locally
ansible-playbook -i inventory ansible/site.yml --check
```

## Security Considerations

1. **Secrets Management**: Never commit secrets to repository
2. **SSH Keys**: Use dedicated keys for CI/CD, rotate regularly
3. **Docker Images**: Scan for vulnerabilities before deployment
4. **Server Access**: Limit SSH access to necessary IPs only

## Customization

### Adding Linting
Install ESLint and update the lint script:
```bash
npm install --save-dev eslint
```

Update package.json:
```json
"lint": "eslint src/ --ext .js"
```

### Adding More Tests
The pipeline supports additional test types:
- Unit tests: `npm test`
- Integration tests: `npm run test:integration`
- E2E tests: `npm run test:e2e`

### Environment-Specific Deployments
Modify the workflow to support staging/production:
```yaml
deploy-staging:
  if: github.ref == 'refs/heads/develop'
  # staging deployment steps

deploy-production:
  if: github.ref == 'refs/heads/main'
  # production deployment steps
```

## Troubleshooting

If deployment fails:
1. Check GitHub Actions logs for specific error messages
2. Verify all secrets are correctly configured
3. Test SSH access manually
4. Ensure Docker Hub repository exists and is accessible
5. Verify Ansible playbook works locally
6. Check server resources (disk space, memory)

For rollback issues:
1. Ensure previous Docker images exist in registry
2. Check Docker Hub API access
3. Verify rollback playbook execution

## Next Steps

After setting up the pipeline:
1. Test with a small change to trigger the workflow
2. Monitor the first few deployments closely
3. Set up additional monitoring and alerting
4. Consider adding deployment approvals for production
5. Implement blue-green deployment for zero downtime