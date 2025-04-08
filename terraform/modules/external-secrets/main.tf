resource "aws_iam_role" "external_secrets" {
  name = "${var.cluster_name}-external-secrets"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub": "system:serviceaccount:external-secrets:external-secrets"
            "${var.oidc_provider}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "external_secrets" {
  name        = "${var.cluster_name}-external-secrets"
  description = "Policy for External Secrets Operator to access Secrets Manager and SSM Parameter Store"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${var.secret_prefix}*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.parameter_prefix}*"
        ]
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version
  namespace  = "external-secrets"
  create_namespace = true

  values = [
    templatefile("${path.module}/templates/values.yaml", {
      role_arn = aws_iam_role.external_secrets.arn
      region   = var.region
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.external_secrets
  ]
}

resource "kubectl_manifest" "secretstore" {
  yaml_body = templatefile("${path.module}/templates/secretstore.yaml", {
    name   = "aws-secretsmanager"
    role_arn = aws_iam_role.external_secrets.arn
    region   = var.region
  })

  depends_on = [
    helm_release.external_secrets
  ]
}

resource "null_resource" "manage_mysql_secret" {
  # Trigger on any change to the secret name or content
  triggers = {
    # The full secret name including the region-specific prefix
    secret_name = "${var.secret_prefix}/mysql"
    password = var.generate_random_password ? "random" : var.mysql_password
    region = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Check if the secret exists (in any state including scheduled for deletion)
      echo "Checking if MySQL secret exists in region ${var.region}..."
      if aws secretsmanager describe-secret --secret-id "${var.secret_prefix}/mysql" --region ${var.region} 2>/dev/null; then
        echo "Secret exists, force deleting..."
        # Force delete the secret without recovery window
        aws secretsmanager delete-secret --secret-id "${var.secret_prefix}/mysql" --force-delete-without-recovery --region ${var.region}
        
        # Wait a moment for deletion to complete
        echo "Waiting for deletion to complete..."
        sleep 5
      else
        echo "Secret doesn't exist, proceeding with creation..."
      fi
    EOT
  }
}

resource "aws_secretsmanager_secret" "mysql" {
  name        = "${var.secret_prefix}/mysql"
  description = "MySQL credentials for EKS application"
  
  tags = var.tags
  
  depends_on = [null_resource.manage_mysql_secret]
}

resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id     = aws_secretsmanager_secret.mysql.id
  secret_string = jsonencode({
    username = "admin"
    password = var.generate_random_password ? random_password.mysql[0].result : var.mysql_password
    host     = "mysql.default.svc.cluster.local"
    port     = "3306"
    database = "app_db"
  })
}

resource "random_password" "mysql" {
  count   = var.generate_random_password ? 1 : 0
  length  = 16
  special = false
}

resource "null_resource" "manage_weather_api_secret" {
  # Trigger on any change to the secret name or content
  triggers = {
    # The full secret name including the region-specific prefix
    secret_name = "${var.secret_prefix}/weather-api"
    api_key = var.weather_api_key
    region = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Check if the secret exists (in any state including scheduled for deletion)
      echo "Checking if Weather API secret exists in region ${var.region}..."
      if aws secretsmanager describe-secret --secret-id "${var.secret_prefix}/weather-api" --region ${var.region} 2>/dev/null; then
        echo "Secret exists, force deleting..."
        # Force delete the secret without recovery window
        aws secretsmanager delete-secret --secret-id "${var.secret_prefix}/weather-api" --force-delete-without-recovery --region ${var.region}
        
        # Wait a moment for deletion to complete
        echo "Waiting for deletion to complete..."
        sleep 5
      else
        echo "Secret doesn't exist, proceeding with creation..."
      fi
    EOT
  }
}

resource "aws_secretsmanager_secret" "weather_api" {
  name        = "${var.secret_prefix}/weather-api"
  description = "Weather API key for EKS application"
  
  tags = var.tags
  
  depends_on = [null_resource.manage_weather_api_secret]
}

resource "aws_secretsmanager_secret_version" "weather_api" {
  secret_id     = aws_secretsmanager_secret.weather_api.id
  secret_string = jsonencode({
    api_key = var.weather_api_key
  })
}

resource "null_resource" "manage_slack_webhook_secret" {
  # Trigger on any change to the secret name or content
  triggers = {
    # The full secret name including the region-specific prefix
    secret_name = "${var.secret_prefix}/slack-webhook"
    webhook_url = var.slack_webhook_url
    region = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Check if the secret exists (in any state including scheduled for deletion)
      echo "Checking if Slack Webhook secret exists in region ${var.region}..."
      if aws secretsmanager describe-secret --secret-id "${var.secret_prefix}/slack-webhook" --region ${var.region} 2>/dev/null; then
        echo "Secret exists, force deleting..."
        # Force delete the secret without recovery window
        aws secretsmanager delete-secret --secret-id "${var.secret_prefix}/slack-webhook" --force-delete-without-recovery --region ${var.region}
        
        # Wait a moment for deletion to complete
        echo "Waiting for deletion to complete..."
        sleep 5
      else
        echo "Secret doesn't exist, proceeding with creation..."
      fi
    EOT
  }
}

resource "aws_secretsmanager_secret" "slack_webhook" {
  name        = "${var.secret_prefix}/slack-webhook"
  description = "Slack webhook URL for Alertmanager notifications"
  
  tags = var.tags
  
  depends_on = [null_resource.manage_slack_webhook_secret]
}

resource "aws_secretsmanager_secret_version" "slack_webhook" {
  secret_id     = aws_secretsmanager_secret.slack_webhook.id
  secret_string = jsonencode({
    webhookUrl = var.slack_webhook_url
  })
}

resource "kubectl_manifest" "mysql_external_secret" {
  yaml_body = templatefile("${path.module}/templates/externalsecret-mysql.yaml", {
    name        = "mysql-secrets"
    namespace   = "default"
    secret_name = aws_secretsmanager_secret.mysql.name
  })

  depends_on = [
    kubectl_manifest.secretstore,
    aws_secretsmanager_secret_version.mysql
  ]
}

resource "kubectl_manifest" "weather_api_external_secret" {
  yaml_body = templatefile("${path.module}/templates/externalsecret-weather.yaml", {
    name        = "weather-api-secrets"
    namespace   = "default"
    secret_name = aws_secretsmanager_secret.weather_api.name
  })

  depends_on = [
    kubectl_manifest.secretstore,
    aws_secretsmanager_secret_version.weather_api
  ]
}

resource "kubectl_manifest" "slack_webhook_external_secret" {
  yaml_body = templatefile("${path.module}/templates/externalsecret-slack.yaml", {
    name        = "slack-webhook-secret"
    namespace   = "monitoring"
    secret_name = aws_secretsmanager_secret.slack_webhook.name
  })

  depends_on = [
    kubectl_manifest.secretstore,
    aws_secretsmanager_secret_version.slack_webhook
  ]
}