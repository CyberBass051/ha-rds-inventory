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
  region = "us-east-1"
}

module "networking" {
  source = "../../modules/networking"

  project_name         = "ha-rds"
  vpc_cidr             = "10.32.0.0/16"
  private_subnet_cidrs = ["10.32.1.0/24", "10.32.2.0/24"]
  az_count             = 2
}

module "database" {
  source = "../../modules/database"

  project_name         = "ha-rds"
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  db_security_group_id = module.networking.db_sg_id
  master_username      = "ha_rds_admin"
  engine_version       = "15.4"
  min_capacity         = 0.5
  max_capacity         = 4
}