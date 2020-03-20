

resource "azurerm_resource_group" "k8s_cluster" {
  name     = "k8s"
  location = "Central US"
}


###############################################################################
# Setup Networking
###############################################################################

resource "azurerm_virtual_network" "k8s" {
  name                = "k8s-network"
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.k8s_cluster.location
  resource_group_name = azurerm_resource_group.k8s_cluster.name
}

resource "azurerm_subnet" "controlplane" {
  name                 = "k8s_controlplane"
  resource_group_name  = azurerm_resource_group.k8s_cluster.name
  virtual_network_name = azurerm_virtual_network.k8s.name
  address_prefix       = "10.0.0.0/24"
}

resource "azurerm_subnet" "workers" {
  name                 = "k8s_controlplane"
  resource_group_name  = azurerm_resource_group.k8s_cluster.name
  virtual_network_name = azurerm_virtual_network.k8s.name
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_network_security_group" "cluster" {
  name                = "k8sSecurityGroup"
  location            = azurerm_resource_group.k8s_cluster.location
  resource_group_name = azurerm_resource_group.k8s_cluster.name

  security_rule {
    name                       = "HttpsInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "443"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "OutboundInternet"
    priority                   = 99
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}
###############################################################################
# Controlplane VMs
###############################################################################

resource "azurerm_network_interface" "controlplane" {
  count               = 3
  name                = "cp-nic-${count.index}"
  location            = azurerm_resource_group.k8s_cluster.location
  resource_group_name = azurerm_resource_group.k8s_cluster.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.controlplane.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "k8s_cp" {
  count               = 3
  name                = "k8s-cp-${count.index}"
  resource_group_name = azurerm_resource_group.k8s_cluster.name
  location            = azurerm_resource_group.k8s_cluster.location
  size                = "Standard_B1s"

  admin_username = "azmin"
  network_interface_ids = [
    azurerm_network_interface.controlplane[count.index].id,
  ]

  admin_ssh_key {
    username   = "azmin"
    public_key = file("~/az/azmin_id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}


