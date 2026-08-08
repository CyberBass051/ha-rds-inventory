variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "db_security_group_id" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "master_user_secret" {
  type = string
}

variable "app_role_name" {
  type = string
}

variable "rds_kms_key_arn" {
  type = string
}

variable "rds_writer_instance_id" {
  type = string
}

variable "vpc_endpoints_security_group_id" {
  type = string
}

variable "app_user_password" {
  type      = string
  sensitive = true
}
