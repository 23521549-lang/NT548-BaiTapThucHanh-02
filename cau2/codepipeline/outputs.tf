output "codecommit_clone_url_http" {
  description = "URL clone CodeCommit repo (HTTPS)"
  value       = aws_codecommit_repository.infra.clone_url_http
}

output "codecommit_clone_url_ssh" {
  description = "URL clone CodeCommit repo (SSH)"
  value       = aws_codecommit_repository.infra.clone_url_ssh
}

output "codepipeline_name" {
  description = "Tên CodePipeline"
  value       = aws_codepipeline.main.name
}

output "codebuild_project_name" {
  description = "Tên CodeBuild project"
  value       = aws_codebuild_project.cfn_lint_test.name
}

output "artifacts_bucket" {
  description = "S3 bucket lưu pipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

output "pipeline_url" {
  description = "URL xem pipeline trên AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.main.name}/view"
}
