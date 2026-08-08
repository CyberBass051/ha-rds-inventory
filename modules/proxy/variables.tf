variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "proxy_security_group_id" {
  type = string
}

variable "db_cluster_resource_id" {
  description = "Aurora cluster resource ID, needed for the IAM auth connection policy"
  type        = string
}

variable "master_user_secret_arn" {
  description = "Scrests Manager ARN from the database module (manage_master_user_password)"
  type        = string
}

variable "db_cluster_identifier" {
  description = "Aurora cluster's identifier (name), used for RDS Proxy target registration"
  type        = string
}

variable "rds_kms_key_arn" {
  type = string
}

variable "app_role_name" {
  type = string
} 