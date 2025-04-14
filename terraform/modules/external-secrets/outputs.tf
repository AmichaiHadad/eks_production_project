output "secretstore_name" {
  description = "Name of the AWS Secrets Manager SecretStore"
  value       = kubectl_manifest.secretstore.name
}

output "external_secrets_role_arn" {
  description = "ARN of the IAM role for External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}

output "mysql_app_user_secret_name" {
  description = "Name of the MySQL app user secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.mysql_app_user.name
}

output "mysql_app_user_password" {
  description = "MySQL app user password (sensitive)"
  value       = random_password.mysql_app_user_password[0].result
  sensitive   = true
}

output "mysql_root_secret_name" {
  description = "Name of the MySQL root secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.mysql_root.name
}

output "weather_api_secret_name" {
  description = "Name of the Weather API secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.weather_api.name
}

output "slack_webhook_secret_name" {
  description = "Name of the Slack webhook secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.slack_webhook.name
}

output "grafana_admin_secret_name" {
  description = "Name of the Grafana admin secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.grafana_admin.name
}
