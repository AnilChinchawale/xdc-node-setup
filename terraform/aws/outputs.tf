output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.xdc.id
}

output "instance_public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.xdc.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the instance"
  value       = aws_instance.xdc.private_ip
}

output "data_volume_id" {
  description = "ID of the data EBS volume"
  value       = aws_ebs_volume.xdc_data.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.xdc.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.xdc.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.xdc.public_ip}"
}
