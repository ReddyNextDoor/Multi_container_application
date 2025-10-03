# Terraform configuration for Todo API deployment infrastructure
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# Sec
urity Group for Todo API server
resource "aws_security_group" "todo_api_sg" {
  name_prefix = "${var.project_name}-${var.environment}-"
  description = "Security group for Todo API server"

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Todo API port
  ingress {
    description = "Todo API"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-security-group"
  }
}

# EC2 Instance for Todo API
resource "aws_instance" "todo_api_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.todo_api_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.todo_api_profile.name
  monitoring            = var.enable_monitoring

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
    encrypted   = true
    
    tags = {
      Name = "${var.project_name}-${var.environment}-root-volume"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
    environment  = var.environment
  }))

  tags = {
    Name = "${var.project_name}-${var.environment}-server"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP for consistent public IP
resource "aws_eip" "todo_api_eip" {
  instance = aws_instance.todo_api_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }

  depends_on = [aws_instance.todo_api_server]
}# Add
itional EBS volume for persistent data storage
resource "aws_ebs_volume" "todo_api_data" {
  availability_zone = aws_instance.todo_api_server.availability_zone
  size              = var.volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.project_name}-${var.environment}-data-volume"
  }
}

# Attach the EBS volume to the instance
resource "aws_volume_attachment" "todo_api_data_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.todo_api_data.id
  instance_id = aws_instance.todo_api_server.id

  # Prevent destruction of the volume when the attachment is destroyed
  skip_destroy = true
}

# VPC configuration (using default VPC for simplicity)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Network ACL for additional security (optional)
resource "aws_network_acl" "todo_api_nacl" {
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  # SSH
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.allowed_ssh_cidr
    from_port  = 22
    to_port    = 22
  }

  # HTTP
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Todo API
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 3000
    to_port    = 3000
  }

  # Ephemeral ports for outbound responses
  ingress {
    protocol   = "tcp"
    rule_no    = 140
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # All outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-nacl"
  }
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "todo_api_logs" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-${var.environment}-logs"
  }
}

# IAM role for EC2 instance (for CloudWatch logs)
resource "aws_iam_role" "todo_api_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-role"
  }
}

# IAM policy for CloudWatch logs
resource "aws_iam_role_policy" "todo_api_cloudwatch_policy" {
  name = "${var.project_name}-${var.environment}-cloudwatch-policy"
  role = aws_iam_role.todo_api_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.todo_api_logs.arn}:*"
      }
    ]
  })
}

# Instance profile for the IAM role
resource "aws_iam_instance_profile" "todo_api_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.todo_api_role.name

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-profile"
  }
}