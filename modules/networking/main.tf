data "aws_availability_zones" "available" {
  state = "available"
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "${var.project_name}-vpc"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# --- Private subnets ---
resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name      = "${var.project_name}-private-${data.aws_availability_zones.available.names[count.index]}"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# --- Route Table ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-private-rt"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_route_table_association" "private_rt_assoc" {
  count          = var.az_count
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}

# --- Security Groups ---
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Write Lambda - egress to RDS Proxy and VPC endpoints only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-lambda-sg"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_security_group" "proxy" {
  name        = "${var.project_name}-proxy-sg"
  description = "RDS Proxy - ingress from Lambda SG only, egress to DB SG only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-proxy-sg"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Aurora Cluster - ingress from Proxy SG only, nothing else"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-db-sg"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}


resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpce-sg"
  description = "Interface VPC endpoints - ingress from Lambda SG on 443"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-vpce-sg"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # Intentionally empty — no ingress, no egress.
  # Forces every resource to use an explicitly-defined SG instead of falling
  # back to the VPC's default-allow-all group.

  tags = {
    Name      = "${var.project_name}-default-sg-locked-down"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

resource "aws_security_group_rule" "lambda_egress_to_proxy" {
  type                     = "egress"
  security_group_id        = aws_security_group.lambda.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.proxy.id
  description              = "Allow write Lambda to reach RDS Proxy"
}

resource "aws_security_group_rule" "proxy_ingress_from_lambda" {
  type                     = "ingress"
  security_group_id        = aws_security_group.proxy.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  description              = "Allow Lambda igress to RDS Proxy"
}

resource "aws_security_group_rule" "proxy_egress_to_db" {
  type                     = "egress"
  security_group_id        = aws_security_group.proxy.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db.id
  description              = "Allow RDS Proxy to reach Aurora cluster"
}

resource "aws_security_group_rule" "db_ingress_from_proxy" {
  type                     = "ingress"
  security_group_id        = aws_security_group.db.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.proxy.id
  description              = "Allow ingress from RDS Proxy only nothing else reaches the DB"
}

resource "aws_security_group_rule" "lambda_egress_to_vpce" {
  type                     = "egress"
  security_group_id        = aws_security_group.lambda.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpc_endpoints.id
  description              = "Allow Lambda traffic to VPC Endpoints"
}

resource "aws_security_group_rule" "vpc_ingress_from_lambda" {
  type                     = "egress"
  security_group_id        = aws_security_group.vpc_endpoints.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  description              = "Allow ingress to VPC Endpoints from Lambda"
}


resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "${var.project_name}-vpce-secretsmanager"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
 

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "${var.project_name}-vpce-logs"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
 
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}-flow-logs"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-vpc-flow-logs"
  }
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.project_name}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type              = "ALL"
  log_destination_type      = "cloud-watch-logs"
  log_destination           = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn              = aws_iam_role.flow_logs.arn
}