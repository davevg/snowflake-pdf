provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project
    }
  }  
}

terraform {
  required_providers {
    aws = ">=5.41.0"
    snowflake = {
      source = "Snowflake-Labs/snowflake"
      version = "0.87.3-pre"
    }
    azurerm = {
        source = "hashicorp/azurerm"
        version = "3.97.1"
    }
    google = {
        source = "hashicorp/google"
        version = "5.21.0"
    }    
  }    
}

provider "azurerm" {
  features {}
}

provider "snowflake" {
  alias = "sysadmin"
  role = "SYSADMIN"
}

provider "snowflake" {
  alias = "account_admin"
  role  = "ACCOUNTADMIN"
}


provider "google" {
  project     = var.google_project
  region      = "us-east1"
}