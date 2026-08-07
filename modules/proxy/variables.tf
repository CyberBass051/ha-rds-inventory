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