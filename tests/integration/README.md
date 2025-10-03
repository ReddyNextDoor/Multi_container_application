# Integration Tests

This directory contains comprehensive integration tests for the Todo API deployment pipeline. These tests validate the entire deployment process from infrastructure provisioning to application deployment and operation.

## Overview

The integration tests are designed to:

1. **Validate Infrastructure**: Test Terraform configurations and AWS resource provisioning
2. **Validate Configuration Management**: Test Ansible playbooks and server configuration
3. **Validate Deployment Process**: Test the complete application deployment pipeline
4. **Validate Data Persistence**: Test database operations and backup/restore functionality
5. **Validate Service Communication**: Test inter-container communication and networking

## Test Structure

### Test Files

- **`infrastructure-validation.test.js`**: Validates Terraform configurations, AWS resources, and infrastructure setup
- **`ansible-validation.test.js`**: Validates Ansible playbooks, roles, templates, and configuration management
- **`deployment-integration.test.js`**: Validates the complete deployment process including application deployment, health checks, and data persistence

### Configuration Files

- **`jest.config.js`**: Jest configuration for integration tests
- **`setup.js`**: Global test setup and utilities
- **`global-setup.js`**: Global setup run before all tests
- **`global-teardown.js`**: Global cleanup run after all tests
- **`test-sequencer.js`**: Custom test sequencer to ensure proper execution order

## Prerequisites

### Required Tools

- **Node.js** (16+)
- **npm** or **yarn**
- **Docker** and **Docker Compose**
- **Terraform** (1.0+)
- **Ansible** (2.9+)
- **AWS CLI** (2.0+)

### Required Accounts and Credentials

- **AWS Account** with appropriate permissions
- **Docker Hub Account** (for image registry)
- **GitHub Repository** (for CI/CD testing)

### Environment Variables

```bash
# AWS Configuration
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"

# Docker Configuration
export DOCKER_USERNAME="your-dockerhub-username"
export DOCKER_PASSWORD="your-dockerhub-password"

# Test Configuration (optional)
export TEST_TIMEOUT="600000"
export TEST_RETRY_ATTEMPTS="3"
export VERBOSE="true"
```

## Running Tests

### Quick Start

```bash
# Install dependencies
npm install

# Run all integration tests
npm run test:integration

# Or use the test runner script
./scripts/run-integration-tests.sh
```

### Test Runner Options

```bash
# Run specific test type
./scripts/run-integration-tests.sh --type infrastructure
./scripts/run-integration-tests.sh --type ansible
./scripts/run-integration-tests.sh --type deployment

# Run with verbose output
./scripts/run-integration-tests.sh --verbose

# Run without cleanup (for debugging)
./scripts/run-integration-tests.sh --no-cleanup

# Run tests in parallel (faster but less debugging info)
./scripts/run-integration-tests.sh --parallel
```

### Individual Test Suites

```bash
# Infrastructure validation only
npx jest --config tests/integration/jest.config.js --testPathPattern infrastructure-validation

# Ansible validation only
npx jest --config tests/integration/jest.config.js --testPathPattern ansible-validation

# Deployment integration only
npx jest --config tests/integration/jest.config.js --testPathPattern deployment-integration
```

## Test Categories

### 1. Infrastructure Validation Tests

**File**: `infrastructure-validation.test.js`

**What it tests**:
- Terraform configuration syntax and validation
- AWS resource availability and permissions
- Security group and network configuration
- IAM roles and policies
- Storage and networking setup

**Prerequisites**:
- AWS credentials configured
- Terraform installed and initialized

**Example**:
```bash
./scripts/run-integration-tests.sh --type infrastructure
```

### 2. Ansible Configuration Tests

**File**: `ansible-validation.test.js`

**What it tests**:
- Ansible playbook syntax and structure
- Role definitions and dependencies
- Template validation
- Handler configuration
- Security best practices

**Prerequisites**:
- Ansible installed
- Playbook files present

**Example**:
```bash
./scripts/run-integration-tests.sh --type ansible
```

### 3. Deployment Integration Tests

**File**: `deployment-integration.test.js`

**What it tests**:
- Complete infrastructure provisioning
- Server configuration with Ansible
- Application deployment
- Health checks and API functionality
- Data persistence and backup/restore
- Service communication

**Prerequisites**:
- All tools installed
- AWS credentials configured
- Docker Hub credentials (optional)

**Example**:
```bash
./scripts/run-integration-tests.sh --type deployment
```

## Test Flow

### Infrastructure Provisioning Flow

1. **Validate Prerequisites**: Check tools and credentials
2. **Create SSH Key Pair**: Generate test key pair in AWS
3. **Provision Infrastructure**: Run Terraform to create resources
4. **Verify Resources**: Validate EC2 instance, security groups, etc.
5. **Test Connectivity**: Verify SSH access to server
6. **Cleanup**: Destroy infrastructure and remove keys

### Server Configuration Flow

1. **Create Inventory**: Generate Ansible inventory for test server
2. **Run Playbooks**: Execute Ansible configuration
3. **Verify Installation**: Check Docker, firewall, etc.
4. **Validate Security**: Verify security configurations
5. **Test Services**: Ensure all services are properly configured

### Application Deployment Flow

1. **Build Images**: Create and push Docker images
2. **Deploy Application**: Use deployment scripts
3. **Health Checks**: Verify application is running
4. **API Testing**: Test all CRUD endpoints
5. **Data Persistence**: Test database operations
6. **Backup/Restore**: Test backup and restore functionality
7. **Service Communication**: Test inter-container networking

## Test Data and Cleanup

### Test Data Management

- Tests create temporary resources with unique identifiers
- All test data includes timestamps and test markers
- Database operations use isolated test collections
- File operations use temporary directories

### Automatic Cleanup

- Infrastructure resources are automatically destroyed
- Docker images and containers are cleaned up
- Temporary files and directories are removed
- Test SSH keys are deleted from AWS

### Manual Cleanup

If tests fail and cleanup doesn't complete:

```bash
# Clean up AWS resources
cd terraform
terraform destroy --auto-approve

# Clean up Docker resources
docker system prune -f
docker volume prune -f

# Clean up SSH keys
aws ec2 delete-key-pair --key-name todo-api-integration-test
rm -f ~/.ssh/todo-api-integration-test.pem
```

## Debugging Tests

### Enable Verbose Output

```bash
export VERBOSE=true
./scripts/run-integration-tests.sh --verbose
```

### Skip Cleanup for Investigation

```bash
./scripts/run-integration-tests.sh --no-cleanup
```

### Run Individual Test Cases

```bash
# Run specific test
npx jest --config tests/integration/jest.config.js --testNamePattern "should provision AWS infrastructure"

# Run with debugging
npx jest --config tests/integration/jest.config.js --detectOpenHandles --forceExit
```

### Check Test Results

```bash
# View test results
cat test-results/integration-test-report.json

# View test logs
ls -la test-results/logs/

# View test artifacts
ls -la test-results/artifacts/
```

## Continuous Integration

### GitHub Actions Integration

Add to your `.github/workflows/ci.yml`:

```yaml
- name: Run Integration Tests
  run: |
    ./scripts/run-integration-tests.sh --type all
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    AWS_REGION: us-east-1
    DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
    DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

### Local CI Simulation

```bash
# Simulate CI environment
export CI=true
export NODE_ENV=test
./scripts/run-integration-tests.sh
```

## Performance Considerations

### Test Duration

- **Infrastructure tests**: ~2-3 minutes
- **Ansible tests**: ~30 seconds
- **Deployment tests**: ~8-10 minutes
- **Total runtime**: ~10-15 minutes

### Resource Usage

- **AWS costs**: Minimal (t3.micro instances for short duration)
- **Network**: Downloads Docker images and packages
- **Disk**: ~2GB for Docker images and test artifacts
- **Memory**: ~4GB recommended for parallel execution

### Optimization Tips

```bash
# Run tests in parallel (faster)
./scripts/run-integration-tests.sh --parallel

# Run specific test types only
./scripts/run-integration-tests.sh --type infrastructure

# Use local Docker registry to avoid pulls
export DOCKER_REGISTRY=localhost:5000
```

## Troubleshooting

### Common Issues

1. **AWS Credentials Not Configured**
   ```bash
   aws configure
   # or
   export AWS_ACCESS_KEY_ID="..."
   export AWS_SECRET_ACCESS_KEY="..."
   ```

2. **Docker Not Running**
   ```bash
   sudo systemctl start docker
   # or
   open -a Docker  # macOS
   ```

3. **Terraform Not Initialized**
   ```bash
   cd terraform
   terraform init
   ```

4. **Port Conflicts**
   ```bash
   # Check for conflicting processes
   lsof -i :3000
   sudo fuser -k 3000/tcp
   ```

5. **Permission Errors**
   ```bash
   # Fix script permissions
   chmod +x scripts/*.sh
   
   # Fix SSH key permissions
   chmod 600 ~/.ssh/*.pem
   ```

### Getting Help

1. **Check test logs**: `test-results/logs/`
2. **Review test artifacts**: `test-results/artifacts/`
3. **Run with verbose output**: `--verbose`
4. **Check individual test files** for specific error handling
5. **Consult the main troubleshooting guide**: `docs/TROUBLESHOOTING.md`

## Contributing

### Adding New Tests

1. **Create test file** in `tests/integration/`
2. **Follow naming convention**: `*.test.js`
3. **Add to test sequencer** if order matters
4. **Update documentation**

### Test Guidelines

- **Use descriptive test names**
- **Include proper cleanup** in `afterAll` blocks
- **Handle async operations** properly
- **Add appropriate timeouts**
- **Include error handling**
- **Document test prerequisites**

### Example Test Structure

```javascript
describe('My Integration Test', () => {
  let testResources = {};
  
  beforeAll(async () => {
    // Setup test resources
  });
  
  afterAll(async () => {
    // Cleanup test resources
  });
  
  test('should do something', async () => {
    // Test implementation
  });
});
```

This integration test suite provides comprehensive validation of the entire Todo API deployment pipeline, ensuring that all components work together correctly in a production-like environment.