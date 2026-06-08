variable "aws_region" {
  description = "AWS region"
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

variable "codecommit_repo_name" {
  description = "Tên CodeCommit repository"
  type        = string
  default     = "nt548-cau2-infra"
}

variable "codecommit_branch" {
  description = "Branch trigger CodePipeline"
  type        = string
  default     = "main"
}

variable "codebuild_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_image" {
  description = "CodeBuild Docker image"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

# Tham số CFN để pass vào deploy stage
variable "cfn_project_name" {
  description = "ProjectName cho CloudFormation stacks"
  type        = string
  default     = "nt548"
}

variable "cfn_environment" {
  description = "Environment cho CloudFormation stacks"
  type        = string
  default     = "dev"
}

variable "cfn_availability_zone" {
  description = "AZ cho CloudFormation stacks"
  type        = string
}

variable "cfn_ami_id" {
  description = "AMI ID cho EC2 stack"
  type        = string
}

variable "cfn_key_pair_name" {
  description = "Key Pair name cho EC2 stack"
  type        = string
}

variable "cfn_allowed_ssh_cidr" {
  description = "CIDR được phép SSH"
  type        = string
}

variable "cfn_vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cfn_public_subnet_cidr" {
  description = "Public Subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "cfn_private_subnet_cidr" {
  description = "Private Subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}
