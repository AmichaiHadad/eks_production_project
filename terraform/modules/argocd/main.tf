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

# Argo CD Helm release
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_helm_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

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

  # Dependencies
  depends_on = [
    kubernetes_namespace.argocd
  ]

  # Wait for Argo CD to be deployed and ready
  timeout    = 600
  wait       = true
  wait_for_jobs = true
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
module "load_balancer_controller_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-account-eks"
  version = "~> 5.0"

  role_name                     = "${var.cluster_name}-lb-controller-role"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.cluster_oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

# Install AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lb_controller_helm_chart_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.load_balancer_controller_irsa.iam_role_arn
  }

  # Schedule on management nodes
  set {
    name  = "nodeSelector.node-role"
    value = "management"
  }

  set {
    name  = "tolerations[0].key"
    value = "management"
  }

  set {
    name  = "tolerations[0].value"
    value = "true"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [
    kubernetes_namespace.argocd
  ]
}