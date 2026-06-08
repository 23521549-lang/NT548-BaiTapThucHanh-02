terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─────────────────────────────────────────────────────────────
# VPC đơn giản chỉ cần 1 public subnet cho Jenkins
# ─────────────────────────────────────────────────────────────
resource "aws_vpc" "jenkins" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-jenkins-vpc" }
}

resource "aws_subnet" "jenkins_public" {
  vpc_id                  = aws_vpc.jenkins.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name_prefix}-jenkins-subnet" }
}

resource "aws_internet_gateway" "jenkins" {
  vpc_id = aws_vpc.jenkins.id
  tags   = { Name = "${local.name_prefix}-jenkins-igw" }
}

resource "aws_route_table" "jenkins" {
  vpc_id = aws_vpc.jenkins.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins.id
  }
  tags = { Name = "${local.name_prefix}-jenkins-rt" }
}

resource "aws_route_table_association" "jenkins" {
  subnet_id      = aws_subnet.jenkins_public.id
  route_table_id = aws_route_table.jenkins.id
}

# ─────────────────────────────────────────────────────────────
# Security Group cho Jenkins EC2
# Port 22  — SSH từ IP chỉ định
# Port 8080 — Jenkins UI
# Port 9000 — SonarQube UI
# Port 3000-3010 — Online Boutique frontend (tuỳ service)
# ─────────────────────────────────────────────────────────────
resource "aws_security_group" "jenkins" {
  name        = "${local.name_prefix}-jenkins-sg"
  description = "Jenkins + SonarQube + Online Boutique"
  vpc_id      = aws_vpc.jenkins.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_web_cidr]
  }

  ingress {
    description = "SonarQube UI"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_web_cidr]
  }

  ingress {
    description = "Online Boutique Frontend"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [var.allowed_web_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-jenkins-sg" }
}

# ─────────────────────────────────────────────────────────────
# EC2 Jenkins Server
# user_data tự động cài: Java, Jenkins, Docker, Docker Compose
# SonarQube chạy bằng Docker Compose
# ─────────────────────────────────────────────────────────────
resource "aws_instance" "jenkins" {
  ami                         = var.ami_id
  instance_type               = var.jenkins_instance_type
  subnet_id                   = aws_subnet.jenkins_public.id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30    # Jenkins + Docker images cần dung lượng
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    dockerhub_username = var.dockerhub_username
    dockerhub_password = var.dockerhub_password
    project_name       = var.project_name
  }))

  tags = { Name = "${local.name_prefix}-jenkins-server" }
}

# Elastic IP để Jenkins URL không đổi sau restart
resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"
  tags     = { Name = "${local.name_prefix}-jenkins-eip" }
}
