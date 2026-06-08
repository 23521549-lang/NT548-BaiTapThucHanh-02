variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "nt548"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "ami_id" {
  description = "AMI ID (Amazon Linux 2 hoặc Ubuntu 22.04)"
  type        = string
}

# Jenkins + SonarQube cần RAM nhiều hơn t2.micro
variable "jenkins_instance_type" {
  description = "EC2 instance type cho Jenkins server (khuyến nghị t3.medium trở lên)"
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "Key Pair để SSH vào EC2"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR được phép SSH (x.x.x.x/32)"
  type        = string
}

variable "allowed_web_cidr" {
  description = "CIDR được phép truy cập Jenkins UI và SonarQube UI (mặc định mở)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_cidr" {
  description = "CIDR cho VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR cho Public Subnet"
  type        = string
  default     = "10.1.1.0/24"
}

# Docker Hub credentials (để push image)
variable "dockerhub_username" {
  description = "Docker Hub username"
  type        = string
  sensitive   = true
}

variable "dockerhub_password" {
  description = "Docker Hub password hoặc access token"
  type        = string
  sensitive   = true
}
