output "proxy_endpoint" {
  value = aws_db_proxy.main.endpoint
}

output "proxy_arn" {
  value = aws_db_proxy.main.arn
}

output "app_user_password" {
  value     = random_password.app_user.result
  sensitive = true
}
