terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region  = "us-east-1"
}

module "networking" {
  source = "../../modules/networking"

  project_name         = "ha-rds"
  vpc_cidr             = "10.32.0.0/16"
  private_subnet_cidrs = ["10.32.1.0/24", "10.32.2.0/24"]
  az_count             = 2
}