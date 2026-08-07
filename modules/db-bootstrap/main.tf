data "aws_ssm_parameter" "psycopg2_layer_arn" {
  name = "/ha-rds/psycopg2-layer-arn"
}

resource "aws_security_group" "bootstrap" {
  name        = "${var.project_name}-db-bootstrap-sg"
  description = "One-time DB role bootstrap Lambda - direct access to Aurora bypasses the proxy"
  vpc_id      = var.vpc_id

  tags = {
    Name      = "${var.project_name}-db-bootstrap-db"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_security_group_rule" "bootstrap_egress_to_db" {
  type                     = "egress"
  security_group_id        = aws_security_group.bootstrap.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.db_security_group_id
  description              = "Bootstrap Lambda reaches Aurora directly to create the app role"
}

resource "aws_security_group_rule" "db_ingress_from_bootstrap" {
  type                     = "ingress"
  security_group_id        = var.db_security_group_id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bootstrap.id
  description              = "Allow one-time bootstrap Lambda to create app_user role"
}

# --- IAM Role for the bootstrap Lambda ---

resource "aws_iam_role" "bootstrap" {
  name = "${var.project_name}-db-bootstrap-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "bootstrap" {
  name = "${var.project_name}-db-bootstrap-policy"
  role = aws_iam_role.bootstrap.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.master_user_secret
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", ]
        Resource = "arn:aws:logs:us-east-1:221717898536:log-group:/aws/lambda/${var.project_name}-db-bootstrap*"
      }
    ]
  })
}

# --- The bootstrap Lambda itself ---

data "archive_file" "bootstrap_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/bootstrap.zip"
}

resource "aws_lambda_function" "bootstrap" {
  function_name                  = "${var.project_name}-db-bootstrap"
  role                           = aws_iam_role.bootstrap.arn
  handler                        = "handler.lambda_handler"
  runtime                        = "python3.12"
  timeout                        = 30
  filename                       = data.archive_file.bootstrap_zip.output_path
  source_code_hash               = data.archive_file.bootstrap_zip.output_base64sha256
  kms_key_arn                    = var.rds_kms_key_arn
  reserved_concurrent_executions = 1

  layers = [data.aws_ssm_parameter.psycopg2_layer_arn.value]

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.bootstrap.id]
  }

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      DB_HOST       = var.cluster_endpoint
      DB_NAME       = "inventory"
      MASTER_SECRET = var.master_user_secret
      APP_ROLE_NAME = var.app_role_name
    }
  }

  tags = {
    Name      = "${var.project_name}-db-bootstrap"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_lambda_invocation" "run_bootstrap" {
  function_name = aws_lambda_function.bootstrap.function_name

  input = jsonencode({
    action = "bootstrap"
  })

  triggers = {
    source_hash = data.archive_file.bootstrap_zip.output_base64sha256
  }
}