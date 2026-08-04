output "vm_name" {
  description = "VM name."
  value       = google_compute_instance.vm.name
}

output "vm_zone" {
  description = "Zone the VM was created in."
  value       = google_compute_instance.vm.zone
}

output "vm_external_ip" {
  description = "Ephemeral external IP."
  value       = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  description = "Ready-to-paste SSH command (uses Intel SOCKS5 proxy via Git for Windows connect.exe)."
  value       = "ssh -F ssh_config vm"
}

output "ssh_command_no_proxy" {
  description = "SSH command without the Intel SOCKS proxy. Use only if you are off Intel's network."
  value       = "ssh -F ssh_config_no_proxy vm"
}
