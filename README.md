# Todo API - Production Deployment

A complete production-ready deployment pipeline for a containerized Node.js Todo API with MongoDB backend, featuring Infrastructure as Code, automated CI/CD, and comprehensive monitoring.

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- Node.js 18+ (for local development)
- AWS CLI (for infrastructure provisioning)
- Terraform (for infrastructure management)
- Ansible (for server configuration)

### Local Development
```bash
# Clone the repository
git clone <repository-url>
cd todo-api

# Start development environment
docker-compose up -d

# Access the API
curl http://localhost:3000/health
```

### Production Deployment
```bash
# 1. Provision infrastructure
./scripts/provision-infrastructure.sh --key-pair your-aws-key --environment production

# 2. Configure server (using output from step 1)
ansible-playbook -i 'SERVER_IP,' ansible/site.yml

# 3. Deploy application
./scripts/deploy.sh --host SERVER_IP --tag your-dockerhub-user/todo-api:latest
```

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Installation & Setup](#installation--setup)
- [Deployment Guide](#deployment-guide)
- [API Documentation](#api-documentation)
- [Infrastructure Management](#infrastructure-management)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub        │    │   Docker Hub    │    │   AWS Cloud     │
│   Repository    │───▶│   Registry      │───▶│   Infrastructure │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                                              │
         ▼                                              ▼
┌─────────────────┐                            ┌─────────────────┐
│   CI/CD         │                            │   Production    │
│   Pipeline      │                            │   Server        │
└─────────────────┘                            └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │   Docker        │
                                               │   Containers    │
                                               │                 │
                                               │  ┌─────────────┐│
                                               │  │   Nginx     ││
                                               │  │   Proxy     ││
                                               │  └─────────────┘│
                                               │  ┌─────────────┐│
                                               │  │   Node.js   ││
                                               │  │   API       ││
                                               │  └─────────────┘│
                                               │  ┌─────────────┐│
                                               │  │   MongoDB   ││
                                               │  │   Database  ││
                                               │  └─────────────┘│
                                               └─────────────────┘
```

## ✨ Features

### Application Features
- **RESTful API**: Full CRUD operations for todo items
- **MongoDB Integration**: Persistent data storage with Mongoose ODM
- **Health Monitoring**: Built-in health check endpoints
- **Error Handling**: Comprehensive error handling and validation
- **CORS Support**: Cross-origin resource sharing enabled

### DevOps Features
- **Infrastructure as Code**: Terraform for AWS resource provisioning
- **Configuration Management**: Ansible for server setup and deployment
- **Containerization**: Docker and Docker Compose for consistent environments
- **CI/CD Pipeline**: GitHub Actions for automated testing and deployment
- **Reverse Proxy**: Nginx with SSL termination and load balancing
- **Backup & Recovery**: Automated database backup and restore scripts
- **Monitoring**: Health checks, logging, and alerting capabilities

## 🛠️ Installation & Setup

### 1. Local Development Setup

```bash
# Install dependencies
npm install

# Copy environment file
cp .env.example .env.development

# Start MongoDB (using Docker)
docker run -d --name mongodb -p 27017:27017 mongo:latest

# Start the application
npm run dev
```

### 2. Docker Development Setup

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### 3. Production Infrastructure Setup

#### Prerequisites
- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- Domain name (optional, for custom domain setup)

#### Step-by-step Setup

1. **Configure AWS Credentials**
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, and region
   ```

2. **Create SSH Key Pair**
   ```bash
   # Create new key pair in AWS
   aws ec2 create-key-pair --key-name todo-api-prod --query 'KeyMaterial' --output text > ~/.ssh/todo-api-prod.pem
   chmod 600 ~/.ssh/todo-api-prod.pem
   ```

3. **Provision Infrastructure**
   ```bash
   ./scripts/provision-infrastructure.sh \
     --key-pair todo-api-prod \
     --environment production \
     --region us-east-1 \
     --type t3.small
   ```

4. **Configure Server**
   ```bash
   # Wait for server to be ready (2-3 minutes)
   # Replace SERVER_IP with the output from previous step
   
   ansible-playbook -i 'SERVER_IP,' ansible/site.yml \
     --private-key ~/.ssh/todo-api-prod.pem
   ```

5. **Set up CI/CD Pipeline**
   
   Add these secrets to your GitHub repository (Settings > Secrets and variables > Actions):
   
   ```
   DOCKER_USERNAME=your-dockerhub-username
   DOCKER_PASSWORD=your-dockerhub-password
   SERVER_HOST=your-server-ip
   SERVER_USER=ubuntu
   SSH_PRIVATE_KEY=contents-of-your-private-key
   ```

## 🚀 Deployment Guide

### Manual Deployment

```bash
# Deploy specific version
./scripts/deploy.sh \
  --host your-server-ip \
  --tag your-dockerhub-user/todo-api:v1.0.0

# Deploy latest version
./scripts/deploy.sh \
  --host your-server-ip \
  --tag your-dockerhub-user/todo-api:latest
```

### Automated Deployment (CI/CD)

The application automatically deploys when you push to the main branch:

1. **Push changes to main branch**
   ```bash
   git add .
   git commit -m "Your changes"
   git push origin main
   ```

2. **Monitor deployment**
   - Go to GitHub Actions tab in your repository
   - Watch the deployment progress
   - Check deployment status and logs

### Rollback

```bash
# Automatic rollback to previous version
./scripts/rollback.sh --host your-server-ip --docker-user your-dockerhub-user

# Rollback to specific version
./scripts/rollback.sh \
  --host your-server-ip \
  --docker-user your-dockerhub-user \
  --tag v1.0.0
```

## 📚 API Documentation

### Base URL
- **Development**: `http://localhost:3000`
- **Production**: `http://your-server-ip` or `https://your-domain.com`

### Endpoints

#### Health Check
```http
GET /health
```
**Response:**
```json
{
  "status": "healthy",
  "database": {
    "status": "connected"
  },
  "timestamp": "2024-10-03T12:00:00.000Z"
}
```

#### Get All Todos
```http
GET /todos
```
**Response:**
```json
{
  "success": true,
  "data": [
    {
      "_id": "507f1f77bcf86cd799439011",
      "title": "Sample Todo",
      "description": "This is a sample todo item",
      "completed": false,
      "createdAt": "2024-10-03T12:00:00.000Z",
      "updatedAt": "2024-10-03T12:00:00.000Z"
    }
  ]
}
```

#### Create Todo
```http
POST /todos
Content-Type: application/json

{
  "title": "New Todo",
  "description": "Description of the new todo"
}
```

#### Get Single Todo
```http
GET /todos/:id
```

#### Update Todo
```http
PUT /todos/:id
Content-Type: application/json

{
  "title": "Updated Todo",
  "description": "Updated description",
  "completed": true
}
```

#### Delete Todo
```http
DELETE /todos/:id
```

### Error Responses
```json
{
  "success": false,
  "error": "Error type",
  "message": "Detailed error message"
}
```

## 🏗️ Infrastructure Management

### Terraform Commands

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy
```

### Ansible Commands

```bash
# Run full playbook
ansible-playbook -i inventory ansible/site.yml

# Run specific role
ansible-playbook -i inventory ansible/site.yml --tags docker

# Check mode (dry run)
ansible-playbook -i inventory ansible/site.yml --check

# Verbose output
ansible-playbook -i inventory ansible/site.yml -v
```

### Environment Management

```bash
# Check environment status
./scripts/manage-environment.sh status --host your-server-ip

# View application logs
./scripts/manage-environment.sh logs --host your-server-ip

# Restart services
./scripts/manage-environment.sh restart --host your-server-ip

# Update application
./scripts/manage-environment.sh update \
  --host your-server-ip \
  --docker-user your-dockerhub-user

# Clean up resources
./scripts/manage-environment.sh cleanup --host your-server-ip
```

## 📊 Monitoring & Maintenance

### Health Monitoring

```bash
# Comprehensive health check
./scripts/health-check.sh --host your-server-ip --verbose

# Quick health check
curl http://your-server-ip/health
```

### Database Backup & Restore

```bash
# Create backup
./scripts/backup-restore.sh backup --host your-server-ip

# Create named backup
./scripts/backup-restore.sh backup \
  --host your-server-ip \
  --name manual_backup_20241003

# List available backups
./scripts/backup-restore.sh list --host your-server-ip

# Restore from backup
./scripts/backup-restore.sh restore \
  --host your-server-ip \
  --name backup_20241003_120000

# Set up automated backups
./scripts/backup-restore.sh schedule --host your-server-ip
```

### Log Management

```bash
# View application logs
docker-compose logs -f todo-api

# View database logs
docker-compose logs -f mongodb

# View nginx logs (if using reverse proxy)
docker-compose logs -f nginx
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Application Won't Start
```bash
# Check container status
docker-compose ps

# Check logs for errors
docker-compose logs todo-api

# Restart services
docker-compose restart
```

#### 2. Database Connection Issues
```bash
# Check MongoDB container
docker-compose logs mongodb

# Verify database connectivity
docker exec -it todo-api-mongodb-1 mongo --eval "db.adminCommand('ismaster')"

# Check environment variables
docker exec todo-api-api-1 env | grep MONGODB
```

#### 3. Deployment Failures
```bash
# Check SSH connectivity
ssh -o ConnectTimeout=10 ubuntu@your-server-ip exit

# Validate Ansible playbook
ansible-playbook ansible/site.yml --syntax-check

# Test deployment script
./scripts/deploy.sh --host your-server-ip --tag your-image:tag
```

#### 4. Health Check Failures
```bash
# Test health endpoint directly
curl -v http://your-server-ip:3000/health

# Check application logs
./scripts/manage-environment.sh logs --host your-server-ip

# Verify all services are running
./scripts/manage-environment.sh status --host your-server-ip
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Set debug environment
export VERBOSE=true

# Run scripts with debug output
./scripts/health-check.sh --host your-server-ip --verbose
./scripts/deploy.sh --host your-server-ip --tag your-image:tag
```

### Performance Issues

```bash
# Check system resources
./scripts/manage-environment.sh status --host your-server-ip

# Monitor container resources
docker stats

# Check disk space
df -h

# Monitor memory usage
free -h
```

## 🤝 Contributing

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Test locally**
   ```bash
   npm test
   docker-compose up -d
   ./scripts/health-check.sh
   ```
5. **Commit and push**
   ```bash
   git commit -m "Add your feature"
   git push origin feature/your-feature-name
   ```
6. **Create a Pull Request**

### Code Standards

- Follow ESLint configuration
- Write tests for new features
- Update documentation for API changes
- Ensure Docker builds succeed
- Test deployment scripts

### Testing

```bash
# Run unit tests
npm test

# Run integration tests
npm run test:integration

# Test Docker build
docker build -t todo-api:test .

# Test deployment locally
docker-compose -f docker-compose.prod.yml up -d
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review existing [GitHub Issues](../../issues)
3. Create a new issue with detailed information
4. Include logs and error messages
5. Specify your environment (development/staging/production)

## 🔗 Related Documentation

- [Environment Setup Guide](docs/ENVIRONMENT_SETUP.md)
- [CI/CD Setup Guide](CI_CD_SETUP.md)
- [Scripts Documentation](scripts/README.md)
- [Ansible Documentation](ansible/README.md)
- [Nginx Configuration](nginx/README.md)
- [SSL Setup Guide](ssl/README.md)