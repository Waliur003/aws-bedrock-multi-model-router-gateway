//Declare Terraform configuration block specifying core version requirements and required AWS and Archive providers
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}


//Declare AWS provider configuration to target specified region and apply global default tags across all Project 5 resources
provider "aws" {
  region = var.aws_region

  # Global default resource tags applied to every provisioned AWS resource
  default_tags {
    tags = {
      Project     = "GenAI-MultiModel-Router"
      Environment = "Production"
      ManagedBy   = "Terraform"
    }
  }
}