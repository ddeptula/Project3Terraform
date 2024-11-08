terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {
     resource_group {
       prevent_deletion_if_contains_resources = false
     }
  }
  subscription_id = "7fdf605c-e6b5-4f51-b9c0-27d0799ce221"
}