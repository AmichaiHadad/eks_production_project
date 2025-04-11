output "secretstore_name" {
  description = "Name of the AWS Secrets Manager SecretStore"
  value       = kubectl_manifest.secretstore.name
}

output "external_secrets_role_arn" {
  description = "ARN of the IAM role for External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}

output "mysql_app_user_secret_name" {
  description = "Name of the MySQL app user secret"
  value       = aws_secretsmanager_secret.mysql_app_user.name
}

output "mysql_app_user_secret_arn" {
  description = "ARN of the MySQL app user secret"
  value       = aws_secretsmanager_secret.mysql_app_user.arn
}

output "mysql_app_user_password" {
  description = "MySQL app user password (sensitive)"
  value       = random_password.mysql_app_user_password[0].result
  sensitive   = true
}

output "weather_api_secret_name" {
  description = "Name of the Weather API secret"
  value       = aws_secretsmanager_secret.weather_api.name
}

output "weather_api_secret_arn" {
  description = "ARN of the Weather API secret"
  value       = aws_secretsmanager_secret.weather_api.arn
}

output "slack_webhook_secret_name" {
  description = "Name of the Slack webhook secret"
  value       = aws_secretsmanager_secret.slack_webhook.name
}

output "grafana_admin_secret_name" {
  description = "Name of the Grafana admin secret"
  value       = aws_secretsmanager_secret.grafana_admin.name
}

output "secret_names_configmap" {
  description = "YAML for a ConfigMap containing all secret names"
  value = yamlencode({
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name = "terraform-secret-outputs"
      namespace = "argocd"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/part-of" = "external-secrets"
      }
    }
    data = {
      mysql_secret_name = aws_secretsmanager_secret.mysql_app_user.name
      weather_api_secret_name = aws_secretsmanager_secret.weather_api.name
      slack_webhook_secret_name = aws_secretsmanager_secret.slack_webhook.name
      grafana_admin_secret_name = aws_secretsmanager_secret.grafana_admin.name
    }
  })
}