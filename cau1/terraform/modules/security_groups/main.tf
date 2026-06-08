locals { name_prefix = "${var.project_name}-${var.environment}" }

resource "aws_security_group" "public_ec2" {
  name        = "${local.name_prefix}-public-ec2-sg"
  description = "Allow SSH from specific IP to Public EC2"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from allowed IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-public-ec2-sg" }
}

resource "aws_security_group" "private_ec2" {
  name        = "${local.name_prefix}-private-ec2-sg"
  description = "Allow SSH only from Public EC2 SG"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH from Public EC2"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_ec2.id]
  }

  ingress {
    description     = "ICMP from Public EC2"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.public_ec2.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-private-ec2-sg" }
}
