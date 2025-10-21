# Guide for Bash Users: Complete Setup

## Visual Directory Structure After Setup

```sh
singapore-infrastructure/
│
├── .gitignore                    # ← Prevents committing sensitive files
├── README.md                     # ← Documentation
│
├── provider.tf                   # ← AWS provider config
├── variables.tf                  # ← Variable declarations  
├── terraform.tfvars              # ← YOUR custom values (gitignored)
│
├── vpc.tf                        # ← VPC, subnets, IGW, routes
├── security_groups.tf            # ← Security group rules
├── key_pair.tf                   # ← SSH key pair
├── ec2.tf                        # ← EC2 instance & EIP
├── outputs.tf                    # ← Output values
│
├── ssh_keys/                     # ← SSH keys (gitignored)
│   ├── id_rsa                    # ← Private key (never share!)
│   └── id_rsa.pub                # ← Public key
│
└── .terraform/                   # ← Created by 'tofu init' (gitignored)
    └── providers/
        └── ...
```

## Step-by-Step: Complete Setup from Scratch

### **Step 1: Create Project Directory Structure**

Open Terminal and run:

```bash
# Navigate to where you want to create the project
cd ~/Documents  # or wherever you prefer

# Create the main project directory
mkdir singapore-infrastructure
cd singapore-infrastructure

# Create the SSH keys subdirectory
mkdir ssh_keys

# Verify you're in the right place
pwd
# Should show: /Users/YOUR_USERNAME/Documents/singapore-infrastructure
```

### **Step 2: Find Your Public IP Address**

You need your public IP to secure SSH access. Here are :

#### **Method 1: Using curl (Fastest)**

```bash
# Get your public IP
curl https://checkip.amazonaws.com

# This shows your external IP as AWS sees it
aws ec2 describe-instances --query 'Reservations[].Instances[].PublicIpAddress' 2>/dev/null || curl https://checkip.amazonaws.com

# Example output: 175.139.207.169 if you connect from Office
```

#### **Method 3: Using AWS CLI**

```bash
# This shows your external IP as AWS sees it
aws ec2 describe-instances --query 'Reservations[].Instances[].PublicIpAddress' 2>/dev/null || curl https://checkip.amazonaws.com
```

**Save your public IP!** You'll use it in format: `YOUR_IP/32`

Example: If your IP is `175.139.207.169`, you'll use `175.139.207.169/32`

### **Step 3: Generate SSH Keys**

Still in the `singapore-infrastructure` directory:

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ssh_keys/id_rsa -N "" -C "singapore-ec2-access"

# You should see:
# Generating public/private rsa key pair.
# Your identification has been saved in ssh_keys/id_rsa
# Your public key has been saved in ssh_keys/id_rsa.pub

# Set correct permissions (IMPORTANT!)
chmod 700 ssh_keys
chmod 600 ssh_keys/id_rsa
chmod 644 ssh_keys/id_rsa.pub

# Verify the keys were created
ls -la ssh_keys/
# Should show:
# -rw-------  1 yourusername  staff  3434 Oct 17 10:30 id_rsa
# -rw-r--r--  1 yourusername  staff   750 Oct 17 10:30 id_rsa.pub
```

### **Step 4: Create All Configuration Files**

Now create each `.tf` file in the **root of your project directory**:

#### **Create .gitignore first**
```bash
cat > .gitignore << 'EOF'
# OpenTofu/Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfstate.backup
.terraform.lock.hcl
terraform.tfvars
terraform.tfvars.json
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# SSH Keys - NEVER commit these!
ssh_keys/
*.pem
*.key
*.ppk

# OS files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# Crash log files
crash.log
crash.*.log
EOF
```

#### **Create provider.tf**
```bash
cat > provider.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "OpenTofu"
      Project     = var.project_name
      CreatedBy   = "DevOps Team"
    }
  }
}
EOF
```

#### **Create variables.tf**
```bash
cat > variables.tf << 'EOF'
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1" # Singapore
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "singapore-infra"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.medium"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH - CHANGE THIS TO YOUR IP!"
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Wide open! Change this!
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 20
}
EOF
```

#### **Create terraform.tfvars (with YOUR IP)**
```bash
# First, get your IP and store it
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "Your public IP is: $MY_IP"

# Create terraform.tfvars with your actual IP
cat > terraform.tfvars << EOF
# Custom configuration values
aws_region       = "ap-southeast-1"
environment      = "production"
project_name     = "singapore-infra"

# SECURITY: Only allow SSH from your IP
allowed_ssh_cidr = ["${MY_IP}/32"]

# EC2 Configuration
instance_type      = "t2.medium"
root_volume_size   = 20
EOF

# Verify the file was created correctly
cat terraform.tfvars
```

#### **Create vpc.tf**
```bash
cat > vpc.tf << 'EOF'
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "Public"
    AZ   = var.availability_zones[count.index]
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
EOF
```

#### **Create security_groups.tf**
```bash
cat > security_groups.tf << 'EOF'
# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instance - managed by OpenTofu"
  vpc_id      = aws_vpc.main.id

  # SSH access - restricted to your IP
  ingress {
    description = "SSH from allowed IPs only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # HTTP access (optional, uncomment if needed)
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access (optional, uncomment if needed)
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
EOF
```

#### **Create key_pair.tf**
```bash
cat > key_pair.tf << 'EOF'
# SSH Key Pair for EC2 Access
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = file("${path.module}/ssh_keys/id_rsa.pub")

  tags = {
    Name = "${var.project_name}-keypair"
  }
}
EOF
```

#### **Create ec2.tf**
```bash
cat > ec2.tf << 'EOF'
# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name

  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-root-volume"
    }
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system
              dnf update -y
              
              # Install essential tools
              dnf install -y \
                git \
                htop \
                tmux \
                wget \
                curl \
                vim \
                nano \
                tree \
                jq \
                nc
              
              # Configure ec2-user
              # ec2-user already exists and is in wheel group
              # Add additional configuration as needed
              
              # Set timezone to Singapore
              timedatectl set-timezone Asia/Singapore
              
              # Create a welcome message
              cat > /etc/motd << 'MOTD'
              ╔════════════════════════════════════════════════╗
              ║   Welcome to Singapore Infrastructure EC2     ║
              ║   Managed by OpenTofu                         ║
              ║   Region: ap-southeast-1                      ║
              ╚════════════════════════════════════════════════╝
              MOTD
              
              # Log completion
              echo "User data script completed at $(date)" >> /var/log/user-data.log
              EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Require IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring = true

  tags = {
    Name = "${var.project_name}-ec2"
  }

  lifecycle {
    ignore_changes = [
      ami,  # Don't force replacement on AMI updates
    ]
  }
}

# Elastic IP
resource "aws_eip" "main" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# Associate EIP with EC2 Instance
resource "aws_eip_association" "main" {
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.main.id
}
EOF
```

#### **Create outputs.tf**
```bash
cat > outputs.tf << 'EOF'
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "security_group_id" {
  description = "EC2 Security Group ID"
  value       = aws_security_group.ec2_sg.id
}

output "ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.main.id
}

output "ec2_private_ip" {
  description = "EC2 Private IP address"
  value       = aws_instance.main.private_ip
}

output "elastic_ip" {
  description = "Elastic IP address (use this to connect)"
  value       = aws_eip.main.public_ip
}

output "elastic_ip_allocation_id" {
  description = "Elastic IP Allocation ID"
  value       = aws_eip.main.id
}

output "ssh_connection_command" {
  description = "Command to SSH into the EC2 instance"
  value       = "ssh -i ssh_keys/id_rsa ec2-user@${aws_eip.main.public_ip}"
}

output "ami_id" {
  description = "AMI ID used for EC2 instance"
  value       = data.aws_ami.amazon_linux.id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = aws_subnet.public[*].availability_zone
}
EOF
```

## Security
- SSH access restricted to your IP only
- IMDSv2 enforced
- Encrypted EBS volumes
- No hardcoded credentials

## Cost
Estimated: ~$35-40 USD/month

### **Step 5: Verify All Files Were Created**

```bash
# List all files in your project
ls -la

# Should see:
# .gitignore
# provider.tf
# variables.tf
# terraform.tfvars
# vpc.tf
# security_groups.tf
# key_pair.tf
# ec2.tf
# outputs.tf
# README.md
# ssh_keys/

# Check line counts to ensure files aren't empty
wc -l *.tf
```

### **Step 6: Verify AWS CLI Configuration**

```bash
# Check if AWS CLI is configured
aws configure list

# Should show:
#       Name                    Value             Type    Location
#       ----                    -----             ----    --------
#    profile                <not set>             None    None
# access_key     ****************ABCD shared-credentials-file    
# secret_key     ****************WXYZ shared-credentials-file    
#     region           ap-southeast-1      config-file    ~/.aws/config

# Test AWS connectivity
aws sts get-caller-identity

# Should show your account details:
# {
#     "UserId": "AIDAXXXXXXXXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }

# Test EC2 access in Singapore region
aws ec2 describe-regions --region ap-southeast-1
```

**If AWS CLI is not configured:**
```bash
aws configure

# Enter when prompted:
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: ap-southeast-1
# Default output format: json
```

### **Step 7: Initialize OpenTofu**

```bash
# Make sure you're in the project directory
cd ~/Documents/singapore-infrastructure

# Initialize OpenTofu (downloads AWS provider)
tofu init

# You should see:
# Initializing the backend...
# Initializing provider plugins...
# - Finding hashicorp/aws versions matching "~> 5.0"...
# - Installing hashicorp/aws v5.x.x...
# OpenTofu has been successfully initialized!
```

### **Step 8: Validate Configuration**

```bash
# Validate all .tf files
tofu validate

# Should see:
# Success! The configuration is valid.

# Format all files (optional but good practice)
tofu fmt

# This will format any unformatted .tf files
```

### **Step 9: Preview What Will Be Created**

```bash
# Run plan to see what will be created
tofu plan

# You should see output like:
# Plan: 14 to add, 0 to change, 0 to destroy.
# 
# Resources to be created:
# + aws_vpc.main
# + aws_subnet.public[0]
# + aws_subnet.public[1]
# + aws_internet_gateway.main
# + aws_route_table.public
# + aws_route_table_association.public[0]
# + aws_route_table_association.public[1]
# + aws_security_group.ec2_sg
# + aws_key_pair.deployer
# + aws_instance.main
# + aws_eip.main
# + aws_eip_association.main

# Review this carefully!
```

### **Step 10: Deploy Infrastructure**

```bash
# Apply the configuration
tofu apply

# Review the plan one more time
# Type 'yes' when prompted

# Deployment takes 2-3 minutes
# You'll see output like:
# aws_vpc.main: Creating...
# aws_vpc.main: Creation complete after 2s
# ...
# Apply complete! Resources: 14 added, 0 changed, 0 destroyed.
```

### **Step 11: Get Connection Information**

```bash
# Get the Elastic IP
tofu output elastic_ip

# Get the full SSH command
tofu output ssh_connection_command

# Or see all outputs
tofu output
```

### **Step 12: Connect to Your EC2 Instance**

```bash
# Copy the SSH command from output or use:
SSH_COMMAND=$(tofu output -raw ssh_connection_command)
echo $SSH_COMMAND

# Connect (first time will ask to verify fingerprint - type 'yes')
eval $SSH_COMMAND

# Or manually:
# ssh -i ssh_keys/id_rsa ec2-user@YOUR_ELASTIC_IP

# If you get "connection refused", wait 30-60 seconds for instance to fully boot
```

### **Step 13: Verify on EC2 Instance**

Once connected:

```bash
# Check system info
uname -a
cat /etc/os-release

# Check your user and permissions
whoami  # Should show: ec2-user
id      # Should show: uid=1000(ec2-user) gid=1000(ec2-user) groups=1000(ec2-user),4(adm),10(wheel)...

# Verify timezone
timedatectl

# Check installed packages
dnf list installed | grep -E 'git|htop|tmux'

# Test internet connectivity
ping -c 3 google.com

# Check AWS metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id

# Check disk space
df -h

# Check memory
free -h
```

## Common Issues & Solutions

### **Issue 1: "Permission denied (publickey)"**

```bash
# Check key permissions
ls -la ssh_keys/id_rsa
# Should be: -rw------- (600)

# Fix if needed
chmod 600 ssh_keys/id_rsa

# Verify key is being used
ssh -vvv -i ssh_keys/id_rsa ec2-user@YOUR_IP
```

### **Issue 2: "Connection timed out"**

```bash
# Verify your IP in terraform.tfvars
cat terraform.tfvars | grep allowed_ssh_cidr

# Update if your IP changed
MY_NEW_IP=$(curl -s https://checkip.amazonaws.com)
echo "allowed_ssh_cidr = [\"${MY_NEW_IP}/32\"]" >> terraform.tfvars

# Apply the change
tofu apply
```

### **Issue 3: "No valid credential sources found"**

```bash
# AWS CLI not configured
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-1"
```

### **Issue 4: Can't find public IP**

```bash
# Your IP might be dynamic - check it again
curl https://checkip.amazonaws.com

# Compare with terraform.tfvars
cat terraform.tfvars | grep allowed_ssh_cidr
```

## Useful Commands Reference

```bash
# Get your current IP anytime
curl -s https://checkip.amazonaws.com

# View current infrastructure
tofu show

# List all resources
tofu state list

# Get specific output
tofu output elastic_ip

# Refresh state
tofu refresh

# Target specific resource
tofu apply -target=aws_instance.main

# View execution plan in detail
tofu plan -out=tfplan

# Destroy everything
tofu destroy  # ⚠️ BE CAREFUL!

# Check OpenTofu version
tofu version

# View provider versions
cat .terraform.lock.hcl
```

## Security Checklist

- SSH access limited to your IP only (/32 CIDR)
- Private SSH keys never committed to Git (in .gitignore)
- EBS volumes encrypted
- IMDSv2 enforced on EC2
- terraform.tfvars in .gitignore
- No hardcoded credentials in code
- Default tags for all resources
- Latest Amazon Linux AMI used