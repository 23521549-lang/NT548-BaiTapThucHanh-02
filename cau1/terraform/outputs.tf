output "vpc_id" {
  value = module.vpc.vpc_id
}
output "public_subnet_id" {
  value = module.vpc.public_subnet_id
}
output "private_subnet_id" {
  value = module.vpc.private_subnet_id
}
output "nat_gateway_id" {
  value = module.nat_gateway.nat_gateway_id
}
output "public_ec2_public_ip" {
  value = module.ec2.public_instance_public_ip
}
output "private_ec2_private_ip" {
  value = module.ec2.private_instance_private_ip
}
output "ssh_public_ec2" {
  value = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${module.ec2.public_instance_public_ip}"
}
output "ssh_private_ec2" {
  value = "ssh -i ~/.ssh/${var.key_pair_name}.pem -J ec2-user@${module.ec2.public_instance_public_ip} ec2-user@${module.ec2.private_instance_private_ip}"
}
