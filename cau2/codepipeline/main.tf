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
# S3 Bucket — lưu artifacts của CodePipeline
# ─────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "${local.name_prefix}-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "${local.name_prefix}-pipeline-artifacts" }
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket                  = aws_s3_bucket.pipeline_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────
# CodeCommit Repository
# ─────────────────────────────────────────────────────────────
resource "aws_codecommit_repository" "infra" {
  repository_name = var.codecommit_repo_name
  description     = "NT548 Cau2 - CloudFormation infrastructure code"
  tags            = { Name = var.codecommit_repo_name }
}

# ─────────────────────────────────────────────────────────────
# IAM Role cho CodeBuild
# ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "codebuild_role" {
  name = "${local.name_prefix}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${local.name_prefix}-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning"]
        Resource = ["${aws_s3_bucket.pipeline_artifacts.arn}", "${aws_s3_bucket.pipeline_artifacts.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudformation:ValidateTemplate",
          "cloudformation:DescribeStacks"
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────
# CodeBuild Project — cfn-lint + taskcat
# ─────────────────────────────────────────────────────────────
resource "aws_codebuild_project" "cfn_lint_test" {
  name          = "${local.name_prefix}-cfn-lint-test"
  description   = "Run cfn-lint and taskcat on CloudFormation templates"
  build_timeout = 30
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "cau2/cloudformation/buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${local.name_prefix}-cfn-lint-test"
      stream_name = "build"
    }
  }

  tags = { Name = "${local.name_prefix}-cfn-lint-test" }
}

# ─────────────────────────────────────────────────────────────
# IAM Role cho CodePipeline
# ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "codepipeline_role" {
  name = "${local.name_prefix}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${local.name_prefix}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning", "s3:ListBucket"]
        Resource = ["${aws_s3_bucket.pipeline_artifacts.arn}", "${aws_s3_bucket.pipeline_artifacts.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["codecommit:GetBranch", "codecommit:GetCommit", "codecommit:UploadArchive", "codecommit:GetUploadArchiveStatus"]
        Resource = aws_codecommit_repository.infra.arn
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = aws_codebuild_project.cfn_lint_test.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack", "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks", "cloudformation:UpdateStack",
          "cloudformation:CreateChangeSet", "cloudformation:DeleteChangeSet",
          "cloudformation:DescribeChangeSet", "cloudformation:ExecuteChangeSet",
          "cloudformation:SetStackPolicy", "cloudformation:ValidateTemplate"
        ]
        Resource = "*"
      },
      {
        # CloudFormation cần tạo VPC, EC2, SG... nên cần passrole + ec2/iam permissions
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = aws_iam_role.cloudformation_deploy_role.arn
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────
# IAM Role cho CloudFormation Deploy (trong CodePipeline)
# ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "cloudformation_deploy_role" {
  name = "${local.name_prefix}-cfn-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudformation.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cfn_deploy_admin" {
  role       = aws_iam_role.cloudformation_deploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# ─────────────────────────────────────────────────────────────
# CodePipeline
# Source (CodeCommit) → Build (cfn-lint+taskcat) → Deploy (CFN stacks)
# ─────────────────────────────────────────────────────────────
resource "aws_codepipeline" "main" {
  name     = "${local.name_prefix}-cfn-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # ── Stage 1: Source từ CodeCommit ──
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName       = aws_codecommit_repository.infra.repository_name
        BranchName           = var.codecommit_branch
        PollForSourceChanges = "true"
      }
    }
  }

  # ── Stage 2: Build — cfn-lint + taskcat ──
  stage {
    name = "Build"
    action {
      name             = "CfnLintAndTaskcat"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.cfn_lint_test.name
      }
    }
  }

  # ── Stage 3: Deploy Stack VPC ──
  stage {
    name = "Deploy-VPC"
    action {
      name            = "DeployVPC"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      version         = "1"
      input_artifacts = ["build_output"]
      configuration = {
        ActionMode         = "CREATE_UPDATE"
        StackName          = "${var.cfn_project_name}-${var.cfn_environment}-vpc"
        TemplatePath       = "build_output::cau2/cloudformation/templates/vpc.yaml"
        RoleArn            = aws_iam_role.cloudformation_deploy_role.arn
        Capabilities       = "CAPABILITY_NAMED_IAM"
        ParameterOverrides = jsonencode({
          ProjectName        = var.cfn_project_name
          Environment        = var.cfn_environment
          VpcCidr            = var.cfn_vpc_cidr
          PublicSubnetCidr   = var.cfn_public_subnet_cidr
          PrivateSubnetCidr  = var.cfn_private_subnet_cidr
          AvailabilityZone   = var.cfn_availability_zone
        })
      }
    }
  }

  # ── Stage 4: Deploy Stack NAT Gateway ──
  stage {
    name = "Deploy-NAT"
    action {
      name            = "DeployNAT"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      version         = "1"
      input_artifacts = ["build_output"]
      configuration = {
        ActionMode         = "CREATE_UPDATE"
        StackName          = "${var.cfn_project_name}-${var.cfn_environment}-nat-gateway"
        TemplatePath       = "build_output::cau2/cloudformation/templates/nat-gateway.yaml"
        RoleArn            = aws_iam_role.cloudformation_deploy_role.arn
        Capabilities       = "CAPABILITY_NAMED_IAM"
        ParameterOverrides = jsonencode({
          ProjectName = var.cfn_project_name
          Environment = var.cfn_environment
        })
      }
    }
  }

  # ── Stage 5: Deploy Route Tables + Security Groups (parallel) ──
  stage {
    name = "Deploy-RT-SG"

    action {
      name            = "DeployRouteTables"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      version         = "1"
      input_artifacts = ["build_output"]
      run_order       = 1
      configuration = {
        ActionMode         = "CREATE_UPDATE"
        StackName          = "${var.cfn_project_name}-${var.cfn_environment}-route-tables"
        TemplatePath       = "build_output::cau2/cloudformation/templates/route-tables.yaml"
        RoleArn            = aws_iam_role.cloudformation_deploy_role.arn
        Capabilities       = "CAPABILITY_NAMED_IAM"
        ParameterOverrides = jsonencode({
          ProjectName = var.cfn_project_name
          Environment = var.cfn_environment
        })
      }
    }

    action {
      name            = "DeploySecurityGroups"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      version         = "1"
      input_artifacts = ["build_output"]
      run_order       = 1
      configuration = {
        ActionMode         = "CREATE_UPDATE"
        StackName          = "${var.cfn_project_name}-${var.cfn_environment}-security-groups"
        TemplatePath       = "build_output::cau2/cloudformation/templates/security-groups.yaml"
        RoleArn            = aws_iam_role.cloudformation_deploy_role.arn
        Capabilities       = "CAPABILITY_NAMED_IAM"
        ParameterOverrides = jsonencode({
          ProjectName     = var.cfn_project_name
          Environment     = var.cfn_environment
          AllowedSshCidr  = var.cfn_allowed_ssh_cidr
        })
      }
    }
  }

  # ── Stage 6: Deploy EC2 ──
  stage {
    name = "Deploy-EC2"
    action {
      name            = "DeployEC2"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      version         = "1"
      input_artifacts = ["build_output"]
      configuration = {
        ActionMode         = "CREATE_UPDATE"
        StackName          = "${var.cfn_project_name}-${var.cfn_environment}-ec2"
        TemplatePath       = "build_output::cau2/cloudformation/templates/ec2.yaml"
        RoleArn            = aws_iam_role.cloudformation_deploy_role.arn
        Capabilities       = "CAPABILITY_NAMED_IAM"
        ParameterOverrides = jsonencode({
          ProjectName  = var.cfn_project_name
          Environment  = var.cfn_environment
          AmiId        = var.cfn_ami_id
          InstanceType = "t2.micro"
          KeyPairName  = var.cfn_key_pair_name
        })
      }
    }
  }

  tags = { Name = "${local.name_prefix}-cfn-pipeline" }
}
