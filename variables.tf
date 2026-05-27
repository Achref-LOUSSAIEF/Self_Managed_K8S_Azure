variable "subscription_id" {
  description = "Azure subscription ID"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "k8s-rg"
}

variable "location" {
  description = "Azure region"
  default     = "eastus"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  default     = "k8s-vnet"
}

variable "vnet_cidr" {
  description = "CIDR block for the virtual network"
  default     = "10.0.0.0/8"
}

variable "control_plane_subnet_name" {
  description = "Name of the control plane subnet"
  default     = "control-plane-subnet"
}

variable "control_plane_subnet_cidr" {
  description = "CIDR block for the control plane subnet"
  default     = "10.0.0.0/16"
}

variable "worker_subnet_name" {
  description = "Name of the worker subnet"
  default     = "worker-subnet"
}

variable "worker_subnet_cidr" {
  description = "CIDR block for the worker subnet"
  default     = "10.1.0.0/16"
}

variable "control_plane_nsg_name" {
  description = "Name of the control plane NSG"
  default     = "control-plane-nsg"
}

variable "worker_nsg_name" {
  description = "Name of the worker NSG"
  default     = "worker-nsg"
}

variable "control_plane_vm_name" {
  description = "Name of the control plane VM"
  default     = "control-plane-vm"
}

variable "worker_vm_name" {
  description = "Name of the worker VM"
  default     = "worker-vm"
}

variable "vm_size" {
  description = "Size of the virtual machines"
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the VMs"
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the VMs and reach the K8s API. Replace with your own IP."
  default     = "0.0.0.0/0" # Replace with your IP, e.g. "203.0.113.10/32"
}
