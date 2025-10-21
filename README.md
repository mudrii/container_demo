# Singapore Infrastructure - AWS with OpenTofu

## Overview

This project creates a complete AWS infrastructure in Singapore (ap-southeast-1) region.

## Complete Project Structure

```sh
singapore-infrastructure/         # Main project directory
├── .gitignore                    # Git ignore file
├── provider.tf                   # AWS provider configuration
├── variables.tf                  # Variable definitions
├── terraform.tfvars              # Your custom variable values
├── vpc.tf                        # VPC, subnets, IGW, routes
├── security_groups.tf            # Security group definitions
├── key_pair.tf                   # SSH key pair resource
├── ec2.tf                        # EC2 instance configuration
├── outputs.tf                    # Output values
├── README.md                     # Documentation
└── ssh_keys/                     # SSH keys directory
    ├── id_rsa                    # Private key
    └── id_rsa.pub                # Public key
```

## Architecture

- Custom VPC (10.0.0.0/16)
- 2 Public Subnets across 2 AZs
- Internet Gateway
- EC2 t2.medium instance with Amazon Linux 2023
- Elastic IP
- Security Groups with SSH restricted to your IP

## Prerequisites

- OpenTofu installed
- AWS CLI configured
- macOS with SSH
- Nushell

## Quick Start

```sh
# Initialize
tofu init

# Plan
tofu plan

# Apply
tofu apply

# Connect
let eip = (tofu output -raw elastic_ip)
ssh -i ssh_keys/id_rsa $"ec2-user@($eip)"
```

## update aws-ami .bashrc to be able to run htop or ncurses apps

```sh
echo 'export TERM=xterm-256color' >> ~/.bashrc
source ~/.bashrc

htop
```

## Security

- SSH access restricted to your IP only
- IMDSv2 enforced
- Encrypted EBS volumes
- No hardcoded credentials

## Cost

Estimated: ~$35-40 USD/month

## Cleanup

```sh
tofu destroy
```
