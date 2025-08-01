terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = local.region
  
  default_tags {
    tags = {
      Environment = "production"
      Project     = "xentra-infra"
      ManagedBy   = "terraform"
    }
  }
}
