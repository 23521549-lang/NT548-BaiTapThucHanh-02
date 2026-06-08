output "public_sg_id" { value = aws_security_group.public_ec2.id }
output "private_sg_id" { value = aws_security_group.private_ec2.id }
