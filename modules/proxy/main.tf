resource "aws_iam_role" "proxy" {
  name = "${var.project_name}-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "proxy_secrets_access" {
  name = "${var.project_name}-proxy-secret-access"
  role = aws_iam_role.proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.master_user_secret_arn
    }]
  })
}

resource "aws_db_proxy" "main" {
  name                   = "${var.project_name}-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.proxy.arn
  vpc_subnet_ids         = var.private_subnet_ids
  vpc_security_group_ids = [var.proxy_security_group_id]
  require_tls            = true

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "REQUIRED"
    secret_arn  = var.master_user_secret_arn
  }

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "REQUIRED"
    secret_arn  = aws_secretsmanager_secret.app_user.arn
  }

  tags = {
    Name      = "${var.project_name}-rds-proxy"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "cluster" {
  db_proxy_name         = aws_db_proxy.main.name
  target_group_name     = aws_db_proxy_default_target_group.main.name
  db_cluster_identifier = var.db_cluster_identifier
}

# IAM policy fragment granting connect access via the Proxy's IAM auth —
# attach this to the write Lambda's execution role in the write-lambda module
data "aws_iam_policy_document" "proxy_connect" {
  statement {
    effect  = "Allow"
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:us-east-1:221717898536:dbuser:${var.db_cluster_resource_id}/${jsondecode(data.aws_secretsmanager_secret_version.master.secret_string)["username"]}"
    ]
  }
}

data "aws_secretsmanager_secret_version" "master" {
  secret_id = var.master_user_secret_arn
}

# --- Create a Secret from DB_USER ---
resource "random_password" "app_user" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "app_user" {
  name       = "${var.project_name}/app-user-credentials"
  kms_key_id = var.rds_kms_key_arn

  tags = {
    Name      = "${var.project_name}-app-user-secret"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "app_user" {
  secret_id = aws_secretsmanager_secret.app_user.id
  secret_string = jsonencode({
    username = var.app_role_name
    password = random_password.app_user.result
  })
}

