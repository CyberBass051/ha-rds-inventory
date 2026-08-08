resource "aws_iam_role" "write" {
  name = "${var.project_name}-write-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "write_db_connect" {
  name = "${var.project_name}-write-db-connect"
  role = aws_iam_role.write.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["rds-db:connect"]
      Resource = "arn:aws:rds-db:us-east-1:221717898536:dbuser:${var.db_cluster_resource_id}/${var.app_role_name}"
    }]
  })
}

resource "aws_iam_role_policy" "write_lambda_base" {
  name = "${var.project_name}-write-lambda-base"
  role = aws_iam_role.write.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:us-east-1:221717898536:log-group:/aws/lambda/${var.project_name}-write*"
      }
    ]
  })
}

# --- Packaging ---
data "archive_file" "write_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/write.zip"
}

resource "aws_lambda_function" "write" {
  function_name    = "${var.project_name}-write-order"
  role             = aws_iam_role.write.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  filename         = data.archive_file.write_zip.output_path
  source_code_hash = data.archive_file.write_zip.output_base64sha256
  kms_key_arn      = var.rds_kms_key_arn

  layers = [data.aws_ssm_parameter.psycopg2_layer_arn.value]

  tracing_config {
    mode = "Active"
  }


  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      PROXY_ENDPOINT = var.proxy_endpoint
      DB_NAME        = "inventory"
      DB_USER        = var.app_role_name
      AWS_REGION_ID  = "us-east-1"
    }
  }

  tags = {
    Name      = "${var.project_name}-write-order"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

data "aws_ssm_parameter" "psycopg2_layer_arn" {
  name = "/ha-rds/psycopg2-layer-arn"
}

# --- API Gateway (HTTP API) ---

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  tags = {
    Name      = "${var.project_name}-api"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_apigatewayv2_integration" "write" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.write.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "orders" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /orders"
  target             = "integrations/${aws_apigatewayv2_integration.write.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Name      = "${var.project_name}-api-stage"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "api_access_logs" {
  name              = "/aws/apigateway/${var.project_name}-api"
  retention_in_days = 14
  kms_key_id        = var.rds_kms_key_arn

  tags = {
    Name      = "${var.project_name}-api-access-logs"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.write.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}