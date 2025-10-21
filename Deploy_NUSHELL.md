# Guide for Nushell Users: Complete Setup

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

## Step-by-Step: Nushell Compatible Setup

### **Step 1: Create Project Directory Structure**

```sh
# Navigate to where you want to create the project
cd ~/Documents  # or wherever you prefer

# Create the main project directory
mkdir singapore-infrastructure
cd singapore-infrastructure

# Create the SSH keys subdirectory
mkdir ssh_keys

# Verify you're in the right place
pwd

# Should show something like: /Users/YOUR_USERNAME/Documents/singapore-infrastructure

# List to confirm
ls
```

### **Step 2: Find Your Public IP Address (Nushell)**

```sh
# Get your public IP using Nushell's http command
http get https://checkip.amazonaws.com | str trim

# Using curl
curl -s https://checkip.amazonaws.com | str trim

# Get IP as AWS sees it
curl -s https://checkip.amazonaws.com | str trim

# Save it to a variable
let my_ip = (http get https://checkip.amazonaws.com | str trim)
print $my_ip

# Example output: 175.139.207.169 if you connect from Office
```

**Remember:** You'll use your IP in format `YOUR_IP/32`

### **Step 3: Generate SSH Keys (Nushell)**

```sh
# Generate SSH key pair (this command is the same)
ssh-keygen -t rsa -b 4096 -f ssh_keys/id_rsa -N "" -C "singapore-ec2-access"

# Set correct permissions (same on macOS)
chmod 700 ssh_keys
chmod 600 ssh_keys/id_rsa
chmod 644 ssh_keys/id_rsa.pub

# Verify the keys were created
ls ssh_keys/ | select name mode size

# Should show:
# ╭───┬────────────┬──────────┬──────╮
# │ # │    name    │   mode   │ size │
# ├───┼────────────┼──────────┼──────┤
# │ 0 │ id_rsa     │ -rw----- │ 3434 │
# │ 1 │ id_rsa.pub │ -rw-r--r │  750 │
# ╰───┴────────────┴──────────┴──────╯
```

### **Step 4: Create All Configuration Files (Nushell)**

#### **Create .gitignore**

```sh
"# OpenTofu/Terraform
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
" | save -f .gitignore
```

#### **Create provider.tf**

```sh
"terraform {
  required_version = \">= 1.6.0\"
  
  required_providers {
    aws = {
      source  = \"hashicorp/aws\"
      version = \"~> 5.0\"
    }
  }
}

provider \"aws\" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = \"OpenTofu\"
      Project     = var.project_name
      CreatedBy   = \"DevOps Team\"
    }
  }
}
" | save -f provider.tf
```

#### **Create variables.tf**

```sh
"variable \"aws_region\" {
  description = \"AWS region for resources\"
  type        = string
  default     = \"ap-southeast-1\" # Singapore
}

variable \"environment\" {
  description = \"Environment name\"
  type        = string
  default     = \"production\"
}

variable \"project_name\" {
  description = \"Project name for resource naming\"
  type        = string
  default     = \"singapore-infra\"
}

variable \"vpc_cidr\" {
  description = \"CIDR block for VPC\"
  type        = string
  default     = \"10.0.0.0/16\"
}

variable \"public_subnet_cidrs\" {
  description = \"CIDR blocks for public subnets\"
  type        = list(string)
  default     = [\"10.0.0.0/24\", \"10.0.1.0/24\"]
}

variable \"availability_zones\" {
  description = \"Availability zones for subnets\"
  type        = list(string)
  default     = [\"ap-southeast-1a\", \"ap-southeast-1b\"]
}

variable \"instance_type\" {
  description = \"EC2 instance type\"
  type        = string
  default     = \"t2.medium\"
}

variable \"allowed_ssh_cidr\" {
  description = \"CIDR blocks allowed to SSH - CHANGE THIS TO YOUR IP!\"
  type        = list(string)
  default     = [\"0.0.0.0/0\"] # WARNING: Wide open! Change this!
}

variable \"root_volume_size\" {
  description = \"Size of root EBS volume in GB\"
  type        = number
  default     = 20
}
" | save -f variables.tf
```

#### **Create terraform.tfvars with YOUR IP (Nushell)**

```sh
# Get your IP and store it
let my_ip = (http get https://checkip.amazonaws.com | str trim)
print $"Your public IP is: ($my_ip)"

# Create terraform.tfvars with your actual IP
$"# Custom configuration values
aws_region       = \"ap-southeast-1\"
environment      = \"production\"
project_name     = \"singapore-infra\"

# SECURITY: Only allow SSH from your IP
allowed_ssh_cidr = [\"($my_ip)/32\"]

# EC2 Configuration
instance_type      = \"t2.medium\"
root_volume_size   = 20
" | save -f terraform.tfvars

# Verify the file was created correctly
open terraform.tfvars
```

#### **Create vpc.tf**

```sh
"# VPC
resource \"aws_vpc\" \"main\" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = \"\${var.project_name}-vpc\"
  }
}

# Internet Gateway
resource \"aws_internet_gateway\" \"main\" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = \"\${var.project_name}-igw\"
  }
}

# Public Subnets
resource \"aws_subnet\" \"public\" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = \"\${var.project_name}-public-subnet-\${count.index + 1}\"
    Type = \"Public\"
    AZ   = var.availability_zones[count.index]
  }
}

# Public Route Table
resource \"aws_route_table\" \"public\" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = \"0.0.0.0/0\"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = \"\${var.project_name}-public-rt\"
  }
}

# Route Table Associations
resource \"aws_route_table_association\" \"public\" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
" | save -f vpc.tf
```

#### **Create security_groups.tf**
```sh
"# Security Group for EC2
resource \"aws_security_group\" \"ec2_sg\" {
  name        = \"\${var.project_name}-ec2-sg\"
  description = \"Security group for EC2 instance - managed by OpenTofu\"
  vpc_id      = aws_vpc.main.id

  # SSH access - restricted to your IP
  ingress {
    description = \"SSH from allowed IPs only\"
    from_port   = 22
    to_port     = 22
    protocol    = \"tcp\"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # HTTP access (optional, uncomment if needed)
  ingress {
    description = \"HTTP from anywhere\"
    from_port   = 80
    to_port     = 80
    protocol    = \"tcp\"
    cidr_blocks = [\"0.0.0.0/0\"]
  }

  # HTTPS access (optional, uncomment if needed)
  ingress {
    description = \"HTTPS from anywhere\"
    from_port   = 443
    to_port     = 443
    protocol    = \"tcp\"
    cidr_blocks = [\"0.0.0.0/0\"]
  }

  # Allow all outbound traffic
  egress {
    description = \"Allow all outbound traffic\"
    from_port   = 0
    to_port     = 0
    protocol    = \"-1\"
    cidr_blocks = [\"0.0.0.0/0\"]
  }

  tags = {
    Name = \"\${var.project_name}-ec2-sg\"
  }

  lifecycle {
    create_before_destroy = true
  }
}
" | save -f security_groups.tf
```

#### **Create key_pair.tf**

```sh
"# SSH Key Pair for EC2 Access
resource \"aws_key_pair\" \"deployer\" {
  key_name   = \"\${var.project_name}-key\"
  public_key = file(\"\${path.module}/ssh_keys/id_rsa.pub\")

  tags = {
    Name = \"\${var.project_name}-keypair\"
  }
}
" | save -f key_pair.tf
```

#### **Create ec2.tf**

```sh
"# Get latest Amazon Linux 2023 AMI
data \"aws_ami\" \"amazon_linux\" {
  most_recent = true
  owners      = [\"amazon\"]

  filter {
    name   = \"name\"
    values = [\"al2023-ami-*-x86_64\"]
  }

  filter {
    name   = \"virtualization-type\"
    values = [\"hvm\"]
  }

  filter {
    name   = \"root-device-type\"
    values = [\"ebs\"]
  }
}

# EC2 Instance
resource \"aws_instance\" \"main\" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name

  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = \"gp3\"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = \"\${var.project_name}-root-volume\"
    }
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system
              dnf update -y
              
              # Install essential tools
              dnf install -y \\
                git \\
                htop \\
                tmux \\
                wget \\
                vim \\
                nano \\
                tree \\
                jq \\
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
              echo \"User data script completed at \$(date)\" >> /var/log/user-data.log
              EOF

  metadata_options {
    http_endpoint               = \"enabled\"
    http_tokens                 = \"required\" # Require IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = \"enabled\"
  }

  monitoring = true

  tags = {
    Name = \"\${var.project_name}-ec2\"
  }

  lifecycle {
    ignore_changes = [
      ami,  # Don't force replacement on AMI updates
    ]
  }
}

# Elastic IP
resource \"aws_eip\" \"main\" {
  domain = \"vpc\"

  tags = {
    Name = \"\${var.project_name}-eip\"
  }

  depends_on = [aws_internet_gateway.main]
}

# Associate EIP with EC2 Instance
resource \"aws_eip_association\" \"main\" {
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.main.id
}
" | save -f ec2.tf
```

#### **Create outputs.tf**

```sh
"output \"vpc_id\" {
  description = \"VPC ID\"
  value       = aws_vpc.main.id
}

output \"vpc_cidr\" {
  description = \"VPC CIDR block\"
  value       = aws_vpc.main.cidr_block
}

output \"public_subnet_ids\" {
  description = \"Public subnet IDs\"
  value       = aws_subnet.public[*].id
}

output \"internet_gateway_id\" {
  description = \"Internet Gateway ID\"
  value       = aws_internet_gateway.main.id
}

output \"security_group_id\" {
  description = \"EC2 Security Group ID\"
  value       = aws_security_group.ec2_sg.id
}

output \"ec2_instance_id\" {
  description = \"EC2 Instance ID\"
  value       = aws_instance.main.id
}

output \"ec2_private_ip\" {
  description = \"EC2 Private IP address\"
  value       = aws_instance.main.private_ip
}

output \"elastic_ip\" {
  description = \"Elastic IP address (use this to connect)\"
  value       = aws_eip.main.public_ip
}

output \"elastic_ip_allocation_id\" {
  description = \"Elastic IP Allocation ID\"
  value       = aws_eip.main.id
}

output \"ssh_connection_command\" {
  description = \"Command to SSH into the EC2 instance\"
  value       = \"ssh -i ssh_keys/id_rsa ec2-user@\${aws_eip.main.public_ip}\"
}

output \"ami_id\" {
  description = \"AMI ID used for EC2 instance\"
  value       = data.aws_ami.amazon_linux.id
}

output \"availability_zones\" {
  description = \"Availability zones used\"
  value       = aws_subnet.public[*].availability_zone
}
" | save -f outputs.tf
```

### **Step 5: Verify All Files Were Created (Nushell)**

```sh
# List all files in your project
ls | where type == file | select name size

# Check for terraform files specifically
ls *.tf | select name size

# Count lines in tf files
ls *.tf | each { |file| 
    { 
        name: $file.name, 
        lines: (open $file.name | lines | length) 
    } 
} | table

# Verify terraform.tfvars contains your IP
open terraform.tfvars | lines | where $it =~ "allowed_ssh_cidr"
```

### **Step 6: Verify AWS CLI Configuration (Nushell)**

```sh
# Check if AWS CLI is configured
aws configure list

# Test AWS connectivity
aws sts get-caller-identity | from json

# Should show structured output:
# ╭─────────┬──────────────────────────────────────╮
# │ UserId  │ AIDAXXXXXXXXXXXXXXXXX                │
# │ Account │ 123456789012                         │
# │ Arn     │ arn:aws:iam::123456789012:user/...   │
# ╰─────────┴──────────────────────────────────────╯

# Test EC2 access in Singapore region
aws ec2 describe-regions --region ap-southeast-1 | from json
```

**If AWS CLI is not configured:**

```sh
# Configure AWS (this launches an interactive prompt)
aws configure

# Or set via environment variables in Nushell
$env.AWS_ACCESS_KEY_ID = "your-access-key"
$env.AWS_SECRET_ACCESS_KEY = "your-secret-key"
$env.AWS_DEFAULT_REGION = "ap-southeast-1"

# Save to env permanently in your config.nu
# Edit: ~/.config/nushell/config.nu
# Add these lines:
# $env.AWS_ACCESS_KEY_ID = "your-access-key"
# $env.AWS_SECRET_ACCESS_KEY = "your-secret-key"
# $env.AWS_DEFAULT_REGION = "ap-southeast-1"
```

### **Step 7: Initialize OpenTofu (Nushell)**

```sh
# Initialize OpenTofu
tofu init

# You should see:
# Initializing the backend...
# Initializing provider plugins...
# - Finding hashicorp/aws versions matching "~> 5.0"...
# - Installing hashicorp/aws v5.x.x...
# OpenTofu has been successfully initialized!
```

### **Step 8: Validate Configuration (Nushell)**

```sh
# Validate all .tf files
tofu validate

# Should see:
# Success! The configuration is valid.

# Format all files
tofu fmt

# Check what was formatted
ls *.tf | select name
```

---

### **Step 9: Preview What Will Be Created (Nushell)**

```sh
# Run plan to see what will be created
tofu plan

# Save plan to a file for review
tofu plan -out=tfplan

# Review the plan output
# You should see something like:
# Plan: 14 to add, 0 to change, 0 to destroy.
```

### **Step 10: Deploy Infrastructure (Nushell)**

```sh
# Apply the configuration
tofu apply

# Or apply with auto-approve (skip confirmation)
# tofu apply -auto-approve
```

### **Step 11: Get Connection Information (Nushell)**

```sh
# Get the Elastic IP
tofu output elastic_ip

# Get just the raw value (no quotes)
let eip = (tofu output -raw elastic_ip)
print $"Your Elastic IP: ($eip)"

# Get the full SSH command
tofu output ssh_connection_command

# Get all outputs as structured data
tofu output -json | from json

# Pretty print all outputs
tofu output -json | from json | table -e
```

### **Step 12: Connect to Your EC2 Instance (Nushell)**

```sh
# Get the Elastic IP and store it
let eip = (tofu output -raw elastic_ip)

# Connect using the stored variable
ssh -i ssh_keys/id_rsa $"ec2-user@($eip)"

# Or in one command
ssh -i ssh_keys/id_rsa $"ec2-user@(tofu output -raw elastic_ip)"

# First time will ask to verify fingerprint - type 'yes'

# If connection refused, wait 30-60 seconds for instance to boot
print "Waiting for instance to be ready..."
sleep 30sec
ssh -i ssh_keys/id_rsa $"ec2-user@($eip)"
```

### **Step 13: Verify on EC2 Instance (Regular Bash)**

Once connected to EC2, you'll be in bash, not nushell:

```bash
# Check system info
uname -a
cat /etc/os-release

# Check your user and permissions
whoami  # Should show: ec2-user
id

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

## Distroy all infrastructure

```sh
# View current infrastructure
tofu show

# List all resources
tofu state list

# Get specific output
tofu output elastic_ip

# Refresh state
tofu refresh

# Check OpenTofu version
tofu version

# View provider versions
cat .terraform.lock.hcl

# Destroy everything with confirmation
tofu destroy

# Or auto-approve (BE CAREFUL!)
# tofu destroy -auto-approve
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
