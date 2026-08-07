variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "lambda_security_group_id" {
  type = string
}

variable "proxy_endpoint" {
  type = string
}

variable "db_cluster_resource_id" {
  type = string
}

variable "app_role_name" {
  type = string
}

variable "rds_kms_key_arn" {
  type = string
}