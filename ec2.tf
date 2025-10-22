# RedHat Enterprise Linux 10 AMI
# EC2 Instance
resource "aws_instance" "main" {
  ami           = "ami-049731af5cd9af3ec" # RHEL 10 x86_64
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
              set -euo pipefail
              
              LOG_FILE="/var/log/user-data.log"
              exec >>"${LOG_FILE}" 2>&1
              echo "User data script started at $(date)"
              
              # Update system packages
              dnf update -y
              
              # Install essential tools
              dnf install -y \
                git \
                tmux \
                wget \
                vim \
                nano \
                tree \
                jq \
                nc \
                curl \
                unzip \
                nmap-ncat
              
              # Install container tools (Podman, Buildah, Skopeo)
              dnf install -y container-tools
           
              # Enable and start Podman socket for Docker API compatibility
              #systemctl enable --now podman.socket
                        
              # Set timezone to Singapore
              timedatectl set-timezone Asia/Singapore

              # Configure terminal for ec2-user
              echo 'export TERM=xterm-256color' >> /home/ec2-user/.bashrc
              echo 'export COLORTERM=truecolor' >> /home/ec2-user/.bashrc
              echo 'alias ll="ls -la --color=auto"' >> /home/ec2-user/.bashrc
              echo 'alias ls="ls --color=auto"' >> /home/ec2-user/.bashrc
              chown ec2-user:ec2-user /home/ec2-user/.bashrc

              echo "User data script completed at $(date)"
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
      ami, # Don't force replacement on AMI updates
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
