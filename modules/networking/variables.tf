variable "project_name" {
  description = "Prefix for resource naming, must match IAM policy scoping (ha-rds-*)"
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_cidrs" {
  description = "One CIDR per AZ, minumum 2 for Multi-AZ-Aurora"
  type        = list(string)
}

variable "az_count" {
  type = number
}

