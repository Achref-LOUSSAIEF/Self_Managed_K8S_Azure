output "control_plane_public_ip" {
  description = "Public IP address of the control plane VM"
  value       = azurerm_public_ip.control_plane_pip.ip_address
}

output "worker_public_ip" {
  description = "Public IP address of the worker VM"
  value       = azurerm_public_ip.worker_pip.ip_address
}
