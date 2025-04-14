/**
 * Argo CD Module
 * Installs Argo CD in the EKS cluster to enable GitOps continuous delivery
 */


# Argo CD Helm release - Install AFTER AWS Load Balancer Controller
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_helm_chart_version
  namespace  = var.namespace

  # Override default values with custom values
  values = [
    templatefile("${path.module}/templates/values.yaml", {
      # Pass variables to values.yaml template
      ingress_enabled       = false  # Disable built-in ingress
      ingress_host          = var.ingress_host
      ingress_tls_secret    = var.ingress_tls_secret
      service_type          = var.service_type
      node_selector         = jsonencode(var.node_selector)
      toleration_key        = var.toleration_key
      toleration_value      = var.toleration_value
      toleration_effect     = var.toleration_effect
    })
  ]

  # Explicitly disable built-in ingress
  set {
    name  = "server.ingress.enabled"
    value = "false"
  }

  # Dependencies - Must deploy LB Controller first to have the webhook ready for ingress validation
  depends_on = [
    helm_release.aws_load_balancer_controller
  ]

  # Wait for Argo CD to be deployed and ready
  timeout    = 900
  wait       = true
  wait_for_jobs = true
  
  # Increase retry attempts
  set {
    name  = "server.initialDelaySeconds"
    value = "30"
  }
}

# Create a custom ingress for ArgoCD that points to the correct service and port
resource "kubernetes_ingress_v1" "argocd_ingress" {
  metadata {
    name      = "argocd-server"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/group.name"      = "argocd"
      "alb.ingress.kubernetes.io/success-codes"   = "200-399"
      "external-dns.alpha.kubernetes.io/hostname" = var.ingress_host
      "external-dns.alpha.kubernetes.io/ttl"      = "300"
      "alb.ingress.kubernetes.io/certificate-arn" = var.ingress_tls_secret
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\":80},{\"HTTPS\":443}]"
    }
  }

  spec {
    ingress_class_name = "alb"
    
    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd
  ]
}

# Wait a bit to ensure ingress controller picks up the ingress
resource "time_sleep" "wait_after_ingress" {
  depends_on      = [kubernetes_ingress_v1.argocd_ingress]
  create_duration = "30s"
}

# Extract the initial admin password
data "kubernetes_secret" "argocd_initial_admin_password" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.namespace
  }
  depends_on = [
    helm_release.argocd
  ]
}

# Create ApplicationSet resource for deploying applications
resource "kubectl_manifest" "applicationset" {
  count = length(var.application_sets)
  yaml_body = templatefile("${path.module}/templates/applicationset.yaml", {
    name        = var.application_sets[count.index].name
    namespace   = var.namespace
    repo_url    = var.application_sets[count.index].repo_url
    path        = var.application_sets[count.index].path
    target_revision = var.application_sets[count.index].target_revision
    target_namespace = var.application_sets[count.index].target_namespace
    auto_sync    = var.application_sets[count.index].auto_sync
    self_heal    = var.application_sets[count.index].self_heal
    values      = var.application_sets[count.index].values
  })
  depends_on = [
    helm_release.argocd
  ]
}

# Create AWS Load Balancer Controller IAM role for service account (IRSA)
resource "aws_iam_role" "load_balancer_controller" {
  name = "${var.cluster_name}-lb-controller-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.cluster_oidc_provider_arn, "/^arn:aws:iam::[0-9]*:oidc-provider\\//", "")}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.cluster_name}-lb-controller-policy"
  description = "Policy for AWS Load Balancer Controller"
  
  policy = file("${path.module}/policies/aws-load-balancer-controller-policy.json")
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

# Install AWS Load Balancer Controller FIRST
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lb_controller_helm_chart_version
  namespace  = "kube-system"

  # All configuration is now in the values block for better YAML handling
  values = [
    <<-EOT
    # Core settings
    clusterName: ${var.cluster_name}
    region: ${var.aws_region}
    
    # Explicitly set VPC ID to avoid IMDS timeout issues
    vpcId: ${var.vpc_id}
    
    serviceAccount:
      create: true
      name: aws-load-balancer-controller
      annotations:
        eks.amazonaws.com/role-arn: ${aws_iam_role.load_balancer_controller.arn}
    
    # Node assignment
    nodeSelector:
      node-role: management
    
    # Tolerations with proper string quoting
    tolerations:
    - key: "${var.toleration_key}"
      value: "${var.toleration_value}"
      effect: "${var.toleration_effect}"
      operator: "Equal"
    
    # Configuration options
    enableCertManager: false
    enableServiceMutatorWebhook: true
    
    # Additional controller args
    extraArgs:
      aws-vpc-id: ${var.vpc_id}
      aws-region: ${var.aws_region}
      cluster-name: ${var.cluster_name}
    EOT
  ]

  # The LB Controller should be independent of ArgoCD
  depends_on = [
    aws_iam_role_policy_attachment.load_balancer_controller
  ]
  
  # Add timeout and wait flags to ensure proper deployment and webhook readiness
  timeout = 900
  wait = true
  wait_for_jobs = true
}
