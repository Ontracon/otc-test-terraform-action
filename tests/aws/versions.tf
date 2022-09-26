terraform {
  required_version = "~> 1"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.11"
    }
  }
}