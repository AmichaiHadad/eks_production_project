output "external_secrets_role_arn" {
  description = "ARN of the IAM role for External Secrets"
  value       = aws_iam_role.external_secrets.arn
}

output "mysql_secret_arn" {
  description = "ARN of the MySQL secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.mysql.arn
}

output "weather_api_secret_arn" {
  description = "ARN of the Weather API secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.weather_api.arn
}

output "mysql_password" {
  description = "Generated MySQL password (if random password generation is enabled)"
  value       = var.generate_random_password ? random_password.mysql[0].result : var.mysql_password
  sensitive   = true
}

output "secretstore_name" {
  description = "Name of the SecretStore created by the module"
  value       = "aws-secretsmanager"  # Hardcoded from the template
}