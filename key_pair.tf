# SSH Key Pair for EC2 Access
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = file("${path.module}/ssh_keys/id_rsa.pub")

  tags = {
    Name = "${var.project_name}-keypair"
  }
}
