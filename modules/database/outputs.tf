output "cluster_id" {
  value = aws_rds_cluster.main.id
}

output "cluster_endpoint" {
  value = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  value = aws_rds_cluster.main.reader_endpoint
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN holding the master credential, since manage_master_user_password=true"
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
}

output "cluster_security_group_id" {
  value = var.db_security_group_id
}