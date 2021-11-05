terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.55.0"
    }
  }
}
provider "azurerm" {
  features {}
}

    # The "feature" block is required for AzureRM provider 2.x. 
    # If you're using version 1.x, the "features" block is not allowed.

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "atulrg-vmlinuxt8"
    location = "west europe"

    tags = {
        environment = "vm Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "atulvnet-vmlinuxt8"
    address_space       = ["10.0.0.0/16"]
    location            = "west europe"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = "vm Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "atulsnet-vmlinuxt8"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "atulpip-vmlinuxt8"
    location                     = "west europe"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "vm Terraform Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "atulnsg-linuxvmt8"
    location            = "west europe"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "86.20.255.82"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "vm Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "atulvnic-vmlinuxt8"
    location                  = "west europe"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

    tags = {
        environment = "vm Terraform Demo"
    }
}

# LAW

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.myterraformnic.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }

    byte_length = 8
}

# Random for LAW
resource "random_string" "tfazmon_lga_suffix" {
  length = 6
  special = false
  upper = false
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "west europe"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "vm Terraform Demo"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 2048
}
output "tls_private_key" { value = tls_private_key.example_ssh.private_key_pem }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    name                  = "atulvm-vmlinuxt8"
    location              = "west europe"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic.id]
    size                  = "Standard_B2s"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "atulvm-vmlinuxt8"
    admin_username = "attila10"
    admin_password = "Santos10Santos10"
    disable_password_authentication = false

    admin_ssh_key {
        username       = "attila10"
    #    public_key     = file("~/.ssh/id_rsa.pub")
        public_key     = tls_private_key.example_ssh.public_key_openssh 
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "vm Terraform Demo"
    }
}
resource "azurerm_log_analytics_workspace" "tfazmon_lga" {
  name                = "atullat8${random_string.tfazmon_lga_suffix.result}"
  location            = azurerm_resource_group.myterraformgroup.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  sku                 = "PerGB2018"
  retention_in_days   = 180
}
resource "azurerm_virtual_machine_extension" "la_ext" {
  name                 = "OmsAgentForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.myterraformvm.id
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "OmsAgentForLinux"
  type_handler_version = "1.13"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "workspaceId": "${azurerm_log_analytics_workspace.tfazmon_lga.workspace_id}"
    }
SETTINGS

    protected_settings = <<PROTECTEDSETTINGS
    {   
        "workspaceKey": "${azurerm_log_analytics_workspace.tfazmon_lga.primary_shared_key}"
    }   
PROTECTEDSETTINGS
}
