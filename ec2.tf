# Get latest RedHat Enterprise Linux 9 AMI
data "aws_ami" "rhel" {
  most_recent = true
  owners      = ["309956199498"]  # RedHat official owner ID

  filter {
    name   = "name"
    values = ["RHEL-9.*-x86_64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami           = data.aws_ami.rhel.id
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
