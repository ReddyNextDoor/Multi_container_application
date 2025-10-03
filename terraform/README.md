# Todo API Terraform Infrastructure

This Terraform configuration creates the necessary AWS infrastructure to deploy the Todo API application.

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform installed** (version >= 1.0)
3. **AWS Key Pair** created for SSH access to the instance

## Quick Start

1. **Clone and navigate to the terraform directory:**
   ```bash
   cd terraform
   ```

2. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars** and set your values:
   ```hcl
   key_pair_name = "your-actual-key-pair-name"
   allowed_ssh_cidr = "your.ip.address/32"  # For better security
   ```

4. **Initialize Terraform:**
   ```bash
   terraform init
   ```

5. **Plan the deployment:**
   ```bash
   terraform plan
   ```

6. **Apply the configuration:**
   ```bash
   terraform apply
   ```

## Environment-Specific Deployments

Use the provided environment-specific variable files:

### Development
```bash
terraform apply -var-file="environments/dev.tfvars" -var="key_pair_name=your-key-name"
```

### Staging
```bash
terraform apply -var-file="environments/staging.tfvars" -var="key_pair_name=your-key-name"
```

### Production
```bash
terraform apply -var-file="environments/prod.tfvars" -var="key_pair_name=your-key-name"
```

## Resources Created

- **EC2 Instance**: Ubuntu 22.04 server with Docker pre-installed
- **Security Group**: Configured for SSH, HTTP, HTTPS, and API access
- **Elastic IP**: Static public IP address
- **EBS Volume**: Additional encrypted storage for data persistence
- **IAM Role & Policy**: For CloudWatch logging
- **CloudWatch Log Group**: For application logs
- **Network ACL**: Additional network-level security

## Outputs

After successful deployment, Terraform will output:

- `instance_public_ip`: Public IP address of the server
- `ssh_connection_command`: Ready-to-use SSH command
- `api_url`: URL where the API will be accessible
- `instance_id`: AWS instance identifier

## SSH Access

Connect to your instance using the output command:
```bash
ssh -i ~/.ssh/your-key-pair.pem ubuntu@<public-ip>
```

## Security Considerations

1. **Restrict SSH access**: Update `allowed_ssh_cidr` to your specific IP range
2. **Key management**: Ensure your SSH private key is secure
3. **Firewall**: The security group allows API access from anywhere - restrict as needed
4. **Monitoring**: Enable detailed monitoring in production environments

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Troubleshooting

### Common Issues

1. **Key pair not found**: Ensure the key pair exists in your AWS region
2. **Permission denied**: Check AWS credentials and IAM permissions
3. **Instance not accessible**: Verify security group rules and network ACLs

### Logs

Check the instance user data execution:
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<ip> 'sudo cat /var/log/cloud-init-output.log'
```

## Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region for resources | `us-east-1` | No |
| `project_name` | Project name for tagging | `todo-api` | No |
| `environment` | Environment (dev/staging/prod) | `prod` | No |
| `instance_type` | EC2 instance type | `t3.micro` | No |
| `key_pair_name` | AWS key pair name | - | Yes |
| `allowed_ssh_cidr` | CIDR for SSH access | `0.0.0.0/0` | No |
| `volume_size` | EBS volume size in GB | `20` | No |
| `enable_monitoring` | Enable detailed monitoring | `false` | No |