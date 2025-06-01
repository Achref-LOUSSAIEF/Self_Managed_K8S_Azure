provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "k8s" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "k8s_vnet" {
  name                = var.vnet_name
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_resource_group.k8s]
}

resource "azurerm_subnet" "control_plane" {
  name                 = var.control_plane_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.k8s_vnet.name
  address_prefixes     = [var.control_plane_subnet_cidr]

  depends_on = [azurerm_virtual_network.k8s_vnet]
}

resource "azurerm_subnet" "worker" {
  name                 = var.worker_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.k8s_vnet.name
  address_prefixes     = [var.worker_subnet_cidr]

  depends_on = [azurerm_virtual_network.k8s_vnet]
}

resource "azurerm_network_security_group" "control_plane_nsg" {
  name                = var.control_plane_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow_SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_K8s_API"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.k8s]
}

resource "azurerm_network_security_group" "worker_nsg" {
  name                = var.worker_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow_SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.k8s]
}

resource "azurerm_subnet_network_security_group_association" "control_plane_assoc" {
  subnet_id                 = azurerm_subnet.control_plane.id
  network_security_group_id = azurerm_network_security_group.control_plane_nsg.id

  depends_on = [azurerm_network_security_group.control_plane_nsg, azurerm_subnet.control_plane]
}

resource "azurerm_subnet_network_security_group_association" "worker_assoc" {
  subnet_id                 = azurerm_subnet.worker.id
  network_security_group_id = azurerm_network_security_group.worker_nsg.id

  depends_on = [azurerm_network_security_group.worker_nsg, azurerm_subnet.worker]
}

resource "azurerm_public_ip" "control_plane_pip" {
  name                = "control-plane-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [azurerm_resource_group.k8s]
}

resource "azurerm_public_ip" "worker_pip" {
  name                = "worker-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  depends_on = [azurerm_resource_group.k8s]
}

resource "azurerm_network_interface" "control_plane_nic" {
  name                = "control-plane-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.control_plane.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.control_plane_pip.id
  }

  depends_on = [azurerm_public_ip.control_plane_pip]
}

resource "azurerm_network_interface" "worker_nic" {
  name                = "worker-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.worker.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.worker_pip.id
  }

  depends_on = [azurerm_public_ip.worker_pip]
}

resource "azurerm_linux_virtual_machine" "control_plane_vm" {
  name                = var.control_plane_vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.control_plane_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-minimal-jammy"
    sku       = "minimal-22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = filebase64("${path.module}/cloud-init/control-plane.yaml")

  depends_on = [azurerm_network_interface.control_plane_nic]
}

resource "azurerm_linux_virtual_machine" "worker_vm" {
  name                = var.worker_vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.worker_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-minimal-jammy"
    sku       = "minimal-22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = filebase64("${path.module}/cloud-init/worker.yaml")

  depends_on = [azurerm_network_interface.worker_nic]
}
