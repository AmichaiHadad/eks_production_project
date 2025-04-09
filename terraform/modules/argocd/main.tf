/**
 * Argo CD Module
 * Installs Argo CD in the EKS cluster to enable GitOps continuous delivery
 */

# Create the argocd namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

# Argo CD Helm release - Install AFTER AWS Load Balancer Controller
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_helm_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  # Removed aggressive recreation options for stable deployments
  # force_update = true
  # replace    = true
  # recreate_pods = true

  # Override default values with custom values
  values = [
    templatefile("${path.module}/templates/values.yaml", {
      # Pass variables to values.yaml template
      ingress_enabled       = var.ingress_enabled
      ingress_host          = var.ingress_host
      ingress_tls_secret    = var.ingress_tls_secret
      service_type          = var.service_type
      node_selector         = jsonencode(var.node_selector)
      toleration_key        = var.toleration_key
      toleration_value      = var.toleration_value
      toleration_effect     = var.toleration_effect
    })
  ]

  # Dependencies - Must deploy LB Controller first to have the webhook ready for ingress validation
  depends_on = [
    kubernetes_namespace.argocd,
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
  
  # Removed aggressive lifecycle policy once deployment is stable
  # lifecycle {
  #   create_before_destroy = true
  # }
}

# Extract the initial admin password
data "kubernetes_secret" "argocd_initial_admin_password" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
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
    namespace   = kubernetes_namespace.argocd.metadata[0].name
    repo_url    = var.application_sets[count.index].repo_url
    path        = var.application_sets[count.index].path
    target_revision = var.application_sets[count.index].target_revision
    target_namespace = var.application_sets[count.index].target_namespace
    auto_sync    = var.application_sets[count.index].auto_sync
    self_heal    = var.application_sets[count.index].self_heal
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
  # Removed aggressive recreation options for stable deployments
  # force_update = true
  # replace    = true
  # recreate_pods = true

  # All configuration is now in the values block for better YAML handling
  values = [
    <<-EOT
    # Core settings
    clusterName: ${var.cluster_name}
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
    EOT
  ]

  # No explicit dependency on ArgoCD namespace - this avoids circular dependency
  # The LB Controller should be independent of ArgoCD
  depends_on = [
    aws_iam_role_policy_attachment.load_balancer_controller
  ]
  
  # Add timeout to ensure proper deployment
  timeout = 900
  
  # Removed aggressive lifecycle policy once deployment is stable
  # lifecycle {
  #   create_before_destroy = true
  # }
}