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
  description = "RHEL 10 AMI ID used for EC2 instance"
  value       = "ami-049731af5cd9af3ec"
}

output "availability_zones" {
  description = "Availability zones used"
  value       = aws_subnet.public[*].availability_zone
}
