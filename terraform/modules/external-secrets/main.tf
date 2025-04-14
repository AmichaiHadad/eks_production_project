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
          "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.secret_prefix}*"
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
          "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.parameter_prefix}*"
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

  set {
    name  = "crds.create"
    value = "false"
  }

  values = [
    templatefile("${path.module}/templates/values.yaml", {
      role_arn = aws_iam_role.external_secrets.arn
      region   = var.aws_region
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
    region   = var.aws_region
  })

  depends_on = [
    helm_release.external_secrets
  ]
}

# Generate random suffixes for secrets
resource "random_string" "mysql_app_user_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "mysql_root_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "weather_api_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "slack_webhook_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "grafana_admin_suffix" {
  length  = 6
  special = false
  upper   = false
}

# --- MySQL App User Secret ---
resource "aws_secretsmanager_secret" "mysql_app_user" {
  name        = "${var.secret_prefix}/mysql-app-user-${random_string.mysql_app_user_suffix.result}"
  description = "MySQL application user credentials for EKS application"
  
  tags = merge(var.tags, {
    status = "active"
  })
}

resource "random_password" "mysql_app_user_password" {
  count   = 1
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret_version" "mysql_app_user" {
  secret_id     = aws_secretsmanager_secret.mysql_app_user.id
  secret_string = jsonencode({
    MYSQL_USER     = var.mysql_app_user
    MYSQL_PASSWORD = random_password.mysql_app_user_password[0].result
    MYSQL_DATABASE = var.mysql_app_database
  })
}

# Handle lifecycle management for MySQL App User Secret
resource "null_resource" "mysql_app_user_tag_cleanup" {
  triggers = {
    secret_arn = aws_secretsmanager_secret.mysql_app_user.arn
    secret_name = aws_secretsmanager_secret.mysql_app_user.name
    aws_region = var.aws_region
  }

  # When this resource is destroyed, update the tag to inactive
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws secretsmanager tag-resource \
        --secret-id ${self.triggers.secret_name} \
        --tags Key=status,Value=inactive \
        --region ${self.triggers.aws_region}
      echo "Updated tag on ${self.triggers.secret_name} to status=inactive"
    EOT
  }
}

# --- MySQL Root Secret ---
resource "aws_secretsmanager_secret" "mysql_root" {
  name        = "${var.secret_prefix}/mysql-root-${random_string.mysql_root_suffix.result}"
  description = "MySQL root password for EKS database"
  
  tags = merge(var.tags, {
    status = "active"
  })
}

# Generate random password for MySQL root within the module
resource "random_password" "mysql_root" {
  count   = 1
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret_version" "mysql_root" {
  secret_id     = aws_secretsmanager_secret.mysql_root.id
  secret_string = jsonencode({
    password = random_password.mysql_root[0].result
  })
}

# Handle lifecycle management for MySQL Root Secret
resource "null_resource" "mysql_root_tag_cleanup" {
  triggers = {
    secret_arn = aws_secretsmanager_secret.mysql_root.arn
    secret_name = aws_secretsmanager_secret.mysql_root.name
    aws_region = var.aws_region
  }

  # When this resource is destroyed, update the tag to inactive
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws secretsmanager tag-resource \
        --secret-id ${self.triggers.secret_name} \
        --tags Key=status,Value=inactive \
        --region ${self.triggers.aws_region}
      echo "Updated tag on ${self.triggers.secret_name} to status=inactive"
    EOT
  }
}

# --- Weather API Secret ---
resource "aws_secretsmanager_secret" "weather_api" {
  name        = "${var.secret_prefix}/weather-api-${random_string.weather_api_suffix.result}"
  description = "Weather API key for EKS application"
  
  tags = merge(var.tags, {
    status = "active"
  })
}

resource "aws_secretsmanager_secret_version" "weather_api" {
  secret_id     = aws_secretsmanager_secret.weather_api.id
  secret_string = jsonencode({
    api_key = var.weather_api_key
  })
}

# Handle lifecycle management for Weather API Secret
resource "null_resource" "weather_api_tag_cleanup" {
  triggers = {
    secret_arn = aws_secretsmanager_secret.weather_api.arn
    secret_name = aws_secretsmanager_secret.weather_api.name
    aws_region = var.aws_region
  }

  # When this resource is destroyed, update the tag to inactive
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws secretsmanager tag-resource \
        --secret-id ${self.triggers.secret_name} \
        --tags Key=status,Value=inactive \
        --region ${self.triggers.aws_region}
      echo "Updated tag on ${self.triggers.secret_name} to status=inactive"
    EOT
  }
}

# --- Slack Webhook Secret ---
resource "aws_secretsmanager_secret" "slack_webhook" {
  name        = "${var.secret_prefix}/slack-webhook-${random_string.slack_webhook_suffix.result}"
  description = "Slack webhook URL for Alertmanager notifications"
  
  tags = merge(var.tags, {
    status = "active"
  })
}

resource "aws_secretsmanager_secret_version" "slack_webhook" {
  secret_id     = aws_secretsmanager_secret.slack_webhook.id
  secret_string = jsonencode({
    webhookUrl = var.slack_webhook_url
  })
}

# Handle lifecycle management for Slack Webhook Secret
resource "null_resource" "slack_webhook_tag_cleanup" {
  triggers = {
    secret_arn = aws_secretsmanager_secret.slack_webhook.arn
    secret_name = aws_secretsmanager_secret.slack_webhook.name
    aws_region = var.aws_region
  }

  # When this resource is destroyed, update the tag to inactive
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws secretsmanager tag-resource \
        --secret-id ${self.triggers.secret_name} \
        --tags Key=status,Value=inactive \
        --region ${self.triggers.aws_region}
      echo "Updated tag on ${self.triggers.secret_name} to status=inactive"
    EOT
  }
}

# --- Grafana Admin Secret ---
resource "random_password" "grafana_admin" {
  count   = 1
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret" "grafana_admin" {
  name        = "${var.secret_prefix}/grafana-admin-${random_string.grafana_admin_suffix.result}"
  description = "Grafana admin credentials"
  
  tags = merge(var.tags, {
    status = "active"
  })
}

resource "aws_secretsmanager_secret_version" "grafana_admin" {
  secret_id     = aws_secretsmanager_secret.grafana_admin.id
  secret_string = jsonencode({
    "admin-user" = "admin"
    "admin-password" = random_password.grafana_admin[0].result
  })
}

# Handle lifecycle management for Grafana Admin Secret
resource "null_resource" "grafana_admin_tag_cleanup" {
  triggers = {
    secret_arn = aws_secretsmanager_secret.grafana_admin.arn
    secret_name = aws_secretsmanager_secret.grafana_admin.name
    aws_region = var.aws_region
  }

  # When this resource is destroyed, update the tag to inactive
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws secretsmanager tag-resource \
        --secret-id ${self.triggers.secret_name} \
        --tags Key=status,Value=inactive \
        --region ${self.triggers.aws_region}
      echo "Updated tag on ${self.triggers.secret_name} to status=inactive"
    EOT
  }
}

# Note: We are now creating K8s secrets directly in this module.
# REMOVED: resource "kubectl_manifest" "secret_prefixes_configmap"

# --- Create Kubernetes Secrets Directly ---

resource "kubernetes_secret_v1" "mysql_root_k8s_secret" {
  metadata {
    name      = var.k8s_root_secret_name
    namespace = var.data_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "external-secrets-module"
    }
  }
  data = {
    # Use the root password generated within this module
    password = base64encode(random_password.mysql_root[0].result)
  }
  type = "Opaque"

  # Ensure AWS secret exists before creating K8s secret
  depends_on = [aws_secretsmanager_secret_version.mysql_root]
}

resource "kubernetes_secret_v1" "mysql_app_k8s_secret" {
  metadata {
    name      = var.k8s_app_secret_name
    namespace = var.data_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "external-secrets-module"
    }
  }
  data = {
    # WARNING: Storing plain text for non-password fields. Standard practice is base64encode.
    "password" = random_password.mysql_app_user_password[0].result
    "username" = var.mysql_app_user
    "database" = var.mysql_app_database
  }
  type = "Opaque"

  # Ensure AWS secret exists before creating K8s secret
  depends_on = [aws_secretsmanager_secret_version.mysql_app_user]
}

resource "kubernetes_secret_v1" "grafana_admin_k8s_secret" {
  metadata {
    name      = var.k8s_grafana_secret_name
    namespace = var.monitoring_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "external-secrets-module"
    }
  }
  data = {
    # Use the admin password generated within this module
    "admin-user"     = base64encode("admin")
    "admin-password" = base64encode(random_password.grafana_admin[0].result)
  }
  type = "Opaque"

  # Ensure AWS secret exists before creating K8s secret
  depends_on = [aws_secretsmanager_secret_version.grafana_admin]
}

resource "kubernetes_secret_v1" "slack_webhook_k8s_secret" {
  # Create only if a webhook URL is provided
  count = var.slack_webhook_url != "" ? 1 : 0 

  metadata {
    name      = var.k8s_slack_secret_name
    namespace = var.monitoring_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "external-secrets-module"
    }
  }
  data = {
    # Use the slack webhook URL provided as input
    # The key name 'slack_webhook_url' might be expected by Alertmanager config
    "slack_webhook_url" = base64encode(var.slack_webhook_url)
  }
  type = "Opaque"

  # Ensure AWS secret exists before creating K8s secret
  depends_on = [aws_secretsmanager_secret_version.slack_webhook]
}

resource "kubernetes_secret_v1" "weather_api_k8s_secret" {
  # Create only if an API key is provided
  count = var.weather_api_key != "" ? 1 : 0

  metadata {
    name      = var.k8s_weather_secret_name
    namespace = var.app_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "external-secrets-module"
    }
  }
  data = {
    # WARNING: Storing plain text for 'api-key'. Standard practice is base64encode.
    "api-key" = var.weather_api_key # Store plain text directly
  }
  type = "Opaque"

  # Ensure AWS secret exists before creating K8s secret
  depends_on = [aws_secretsmanager_secret_version.weather_api]
}

# Create a duplicate of the MySQL App credentials secret in the app namespace
resource "kubernetes_secret_v1" "mysql_app_k8s_secret_for_app" {
  metadata {
    name      = var.k8s_app_mysql_secret_name
    namespace = var.app_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "external-secrets-module"
    }
  }
  data = {
    # WARNING: Storing plain text for non-password fields. Standard practice is base64encode.
    "password" = random_password.mysql_app_user_password[0].result
    "username" = var.mysql_app_user
    "database" = var.mysql_app_database
  }
  type = "Opaque"

  # Ensure AWS secret exists before creating K8s secret
  depends_on = [aws_secretsmanager_secret_version.mysql_app_user]
}