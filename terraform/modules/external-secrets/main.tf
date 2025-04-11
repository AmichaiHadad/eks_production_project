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

# Create a ConfigMap to store all secret names
resource "kubectl_manifest" "secret_names_configmap" {
  yaml_body = yamlencode({
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
    username = "app_user"
    password = random_password.mysql_app_user_password[0].result
    host     = "mysql.data.svc.cluster.local"
    port     = "3306"
    database = "app_db"
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

# Note: We will create ExternalSecret resources via Helm charts in the correct application namespaces instead.

resource "kubectl_manifest" "secret_retrieval_job" {
  yaml_body = <<-EOF
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: aws-secret-retriever
      namespace: argocd
      labels:
        app.kubernetes.io/managed-by: terraform
        app.kubernetes.io/part-of: external-secrets
    spec:
      template:
        spec:
          serviceAccountName: external-secrets
          containers:
          - name: aws-cli
            image: amazon/aws-cli:latest
            command:
            - /bin/bash
            - -c
            - |
              # Get the MySQL secret name
              SECRET_NAME=$(aws secretsmanager list-secrets --filters Key=name,Values=${var.secret_prefix}/mysql-app-user --query "SecretList[0].Name" --output text)
              
              # Create ConfigMap with the secret name
              cat > /tmp/configmap.yaml << EOL
              apiVersion: v1
              kind: ConfigMap
              metadata:
                name: mysql-secret-name
                namespace: data
                labels:
                  app.kubernetes.io/managed-by: terraform
                  app.kubernetes.io/part-of: external-secrets
              data:
                aws-secret-name: "$SECRET_NAME"
              EOL
              
              # Install kubectl
              curl -LO "https://dl.k8s.io/release/v1.27.0/bin/linux/amd64/kubectl"
              chmod +x kubectl
              mv kubectl /usr/local/bin/
              
              # Apply the ConfigMap
              kubectl apply -f /tmp/configmap.yaml
            env:
            - name: AWS_REGION
              value: ${var.aws_region}
          restartPolicy: OnFailure
      backoffLimit: 3
  EOF

  depends_on = [
    helm_release.external_secrets,
    aws_secretsmanager_secret.mysql_app_user
  ]
}

resource "kubectl_manifest" "secret_prefixes_configmap" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name = "aws-secret-prefixes"
      namespace = "external-secrets"
    }
    data = {
      mysql_secret_prefix = "${var.secret_prefix}/mysql-app-user"
      weather_api_prefix = "${var.secret_prefix}/weather-api"
      slack_webhook_prefix = "${var.secret_prefix}/slack-webhook"
      grafana_admin_prefix = "${var.secret_prefix}/grafana-admin"
    }
  })

  depends_on = [
    helm_release.external_secrets
  ]
}