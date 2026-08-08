output "proxy_endpoint" {
  value = aws_db_proxy.main.endpoint
}

output "proxy_arn" {
  value = aws_db_proxy.main.arn
}

output "proxy_connect_policy_json" {
  description = "Attach this to the write Lambda's execution role"
  value       = data.aws_iam_policy_document.proxy_connect.json
}

output "app_user_password" {
  value     = random_password.app_user.result
  sensitive = true
}