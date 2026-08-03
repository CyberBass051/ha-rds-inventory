output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "lambda_sg_id" {
  value = aws_security_group.lambda.id
}

output "proxy_sg_id" {
  value = aws_security_group.proxy.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}
