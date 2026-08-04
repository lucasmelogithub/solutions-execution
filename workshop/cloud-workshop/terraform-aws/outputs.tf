output "public_ip" {
  description = "Public IP of the Xeon 6 instance."
  value       = aws_instance.vm.public_ip
}

output "ssh_command" {
  description = "Command to SSH into the Xeon 6 instance."
  value       = "ssh -F ssh_config vm"
}

output "instance_type" {
  description = "Instance type deployed."
  value       = aws_instance.vm.instance_type
}
