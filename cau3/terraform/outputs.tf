output "jenkins_public_ip" {
  description = "Public IP của Jenkins server"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins UI URL"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "sonarqube_url" {
  description = "SonarQube UI URL"
  value       = "http://${aws_eip.jenkins.public_ip}:9000"
}

output "boutique_url" {
  description = "Online Boutique Frontend URL (sau khi chạy pipeline)"
  value       = "http://${aws_eip.jenkins.public_ip}:8081"
}

output "ssh_command" {
  description = "Lệnh SSH vào Jenkins server"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.jenkins.public_ip}"
}

output "get_jenkins_password" {
  description = "Lệnh lấy Jenkins initial admin password"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.jenkins.public_ip} 'cat /opt/nt548/jenkins-initial-password.txt'"
}
