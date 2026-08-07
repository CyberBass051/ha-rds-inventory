terraform {
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

module "proxy" {
  source = "../../modules/proxy"

  project_name            = "ha-rds"
  vpc_id                  = module.networking.vpc_id
  private_subnet_ids      = module.networking.private_subnet_ids
  proxy_security_group_id = module.networking.proxy_sg_id
  db_cluster_resource_id  = module.database.cluster_resource_id
  master_user_secret_arn  = module.database.master_user_secret_arn
}

module "bootstrap" {
  source = "../../modules/db-bootstrap"

  project_name         = "ha-rds"
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  db_security_group_id = module.networking.db_sg_id
  cluster_endpoint     = module.database.cluster_endpoint
  master_user_secret   = module.database.master_user_secret_arn
  app_role_name        = "app_user"
  rds_kms_key_arn      = module.database.rds_kms_key_arn
}

module "write_lambda" {
  source = "../../modules/write-lambda"

  project_name             = "ha-rds"
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  lambda_security_group_id = module.networking.lambda_sg_id
  proxy_endpoint           = module.proxy.proxy_endpoint
  db_cluster_resource_id   = module.database.cluster_resource_id
  app_role_name            = "app_user"
  rds_kms_key_arn          = module.database.rds_kms_key_arn
}