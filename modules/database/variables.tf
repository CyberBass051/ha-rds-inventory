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

variable "master_username" {
  type = string
}

variable "engine_version" {
  description = "Aurora PostreSQL engine version supporting serverless v2"
  type        = string
}

variable "min_capacity" {
  description = "Aurora Serverless v2 min ACU"
  type        = number
}

variable "max_capacity" {
  description = "Aurora Serverless v2 max ACU"
  type        = number
}

