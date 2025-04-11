resource "aws_iam_role" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"
  
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
            "${var.oidc_provider}:sub": "system:serviceaccount:karpenter:karpenter-controller"
            "${var.oidc_provider}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.cluster_name}-karpenter-controller"
  description = "IAM policy for Karpenter controller"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:TerminateInstances",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts",
          "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = var.node_iam_role_arn
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = var.cluster_arn
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version
  namespace  = "karpenter"
  create_namespace = true

  set {
    name  = "crds.create"
    value = "false"
  }

  values = [
    templatefile("${path.module}/templates/values.yaml", {
      cluster_name      = var.cluster_name
      cluster_endpoint  = var.cluster_endpoint
      iam_role_arn      = aws_iam_role.karpenter_controller.arn
      node_role_arn     = var.node_iam_role_arn
    })
  ]

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }

  set {
    name = "serviceAccount.create"
    value = "true"
  }

  set {
    name = "serviceAccount.name"
    value = "karpenter-controller"
  }

  set {
    name = "settings.aws.interruptionQueueName"
    value = var.cluster_name
  }

  set {
    name = "controller.resources.requests.cpu"
    value = "200m"
  }

  set {
    name = "controller.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name = "controller.resources.limits.memory"
    value = "1Gi"
  }

  set {
    name = "nodeSelector.node-role"
    value = "management"
  }

  set {
    name  = "tolerations[0].key"
    value = "management"
  }

  set {
    name  = "tolerations[0].value"
    value = "true"
    type  = "string"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Equal"
  }

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller,
    helm_release.karpenter
  ]
}

resource "time_sleep" "wait_for_karpenter_crds" {
  create_duration = "30s" # Wait 30 seconds after Helm release

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = templatefile("${path.module}/templates/nodepool.yaml", {
    cluster_name    = var.cluster_name
    cluster_endpoint = var.cluster_endpoint
    subnet_ids      = join(",", var.private_subnet_ids)
    security_groups = join(",", var.security_group_ids)
    region          = var.aws_region
    node_role_name = var.node_role_name
  })

  depends_on = [
    helm_release.karpenter,
    time_sleep.wait_for_karpenter_crds
  ]
}