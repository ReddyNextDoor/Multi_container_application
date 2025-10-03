# Output values for Terraform configuration

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.todo_api_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.todo_api_eip.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.todo_api_server.public_dns
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.todo_api_server.private_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.todo_api_sg.id
}

output "key_pair_name" {
  description = "Name of the key pair used"
  value       = var.key_pair_name
}

output "ssh_connection_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.todo_api_eip.public_ip}"
}

output "api_url" {
  description = "URL to access the Todo API"
  value       = "http://${aws_eip.todo_api_eip.public_ip}:3000"
}

output "volume_id" {
  description = "ID of the EBS volume"
  value       = aws_ebs_volume.todo_api_data.id
}