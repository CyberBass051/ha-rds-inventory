resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name      = "${var.project_name}-db-subnet-group"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_rds_cluster_parameter_group" "main" {
  name        = "${var.project_name}-cluster-pg"
  family      = "aurora-postgresql15"
  description = "Cluster parameter group for ${var.project_name} - enforces SSL"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = {
    Name      = "${var.project_name}-cluster-pg"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for Aurora cluster storage encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name      = "${var.project_name}-rds-kms"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_rds_cluster" "main" {
  cluster_identifier              = "${var.project_name}-cluster"
  engine                          = "aurora-postgresql"
  engine_mode                     = "provisioned"
  engine_version                  = var.engine_version
  database_name                   = "inventory"
  master_username                 = var.master_username
  manage_master_user_password     = true
  db_subnet_group_name            = aws_db_subnet_group.main.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  vpc_security_group_ids          = [var.db_security_group_id]
  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.rds.arn
  backup_retention_period         = 7
  preferred_backup_window         = "03:00-04:00"
  deletion_protection             = false
  skip_final_snapshot             = true

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }
  tags = {
    Name      = "${var.project_name}-cluster"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_rds_cluster_instance" "writer" {
  cluster_identifier   = aws_rds_cluster.main.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.main.engine
  engine_version       = aws_rds_cluster.main.engine_version
  db_subnet_group_name = aws_db_subnet_group.main.name

  tags = {
    Name      = "${var.project_name}-write-instance"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_rds_cluster_instance" "reader" {
  cluster_identifier   = aws_rds_cluster.main.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.main.engine
  engine_version       = aws_rds_cluster.main.engine_version
  db_subnet_group_name = aws_db_subnet_group.main.name

  tags = {
    Name      = "${var.project_name}-reader-instance"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}