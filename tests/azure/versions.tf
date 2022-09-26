terraform {
  required_version = "~> 1"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.2.0"
    }
  }
}