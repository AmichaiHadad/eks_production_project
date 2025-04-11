resource "aws_iam_role" "keda_controller" {
  name = "${var.cluster_name}-keda-controller"
  
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
            "${var.oidc_provider}:sub": "system:serviceaccount:keda:keda-operator"
            "${var.oidc_provider}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "keda_controller" {
  name        = "${var.cluster_name}-keda-controller"
  description = "IAM policy for KEDA controller"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "keda_controller" {
  role       = aws_iam_role.keda_controller.name
  policy_arn = aws_iam_policy.keda_controller.arn
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.keda_chart_version
  namespace  = "keda"
  create_namespace = true

  set {
    name = "crds.create"
    value = "false"
  }

  values = [
    templatefile("${path.module}/templates/values.yaml", {
      iam_role_arn = aws_iam_role.keda_controller.arn
    })
  ]

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.keda_controller.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.keda_controller
  ]
}

resource "kubectl_manifest" "keda_scaled_object" {
  yaml_body = templatefile("${path.module}/templates/scaled-object.yaml", {
    deployment_name = var.app_deployment_name
    namespace      = var.app_namespace
    prometheus_url = var.prometheus_url
  })

  depends_on = [
    helm_release.keda
  ]
}