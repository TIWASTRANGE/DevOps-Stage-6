output "server_public_ip" {
  description = "Public IP of the server"
  value       = aws_instance.micro_todo_app_server.public_ip
}

output "server_id" {
  description = "Instance ID"
  value       = aws_instance.micro_todo_app_server.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.micro_todo_app_sg.id
}

output "ssh_command" {
  description = "SSH command to connect to server"
  value       = "ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${aws_instance.micro_todo_app_server.public_ip}"
}