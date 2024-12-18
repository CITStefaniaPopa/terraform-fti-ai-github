terraform {
  required_version = ">=1.5.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.84.0"
    }
     azuread = {
      source  = "hashicorp/azuread"
      version = "2.53.1"
    }
  }

     

     backend "azurerm" {
      subscription_id      = "8183f26d-8d65-42c0-8ac9-9e08e98b04d3"
      resource_group_name  = "test-state"
      storage_account_name = "firsteststate"
      container_name       = "tfstate"
      key                  = "terraform.tfstate"
      access_key           = "05CSOPwKwPEbz1q0GpbuW+bxfZt7sDV5Od6eNIzdeOA4B2ZUFQmHR16XMeGKtgfuJeXCU+FFU4WJ+AStd/rDkw=="
  }
}

provider "azurerm" {
  subscription_id   = "8183f26d-8d65-42c0-8ac9-9e08e98b04d3"
  features {}
}

provider "azurerm" {
  alias           = "hub_network"
  subscription_id = "6be149cf-200d-45f6-ba7e-838e9f33239f"
  features {}
}

data "azurerm_client_config" "hub_network" {
   provider = azurerm.hub_network
}

data "azurerm_subscription" "hub_network" {
   provider            = azurerm.hub_network
}
 
data "azurerm_client_config" "current" {
}
