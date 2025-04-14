/**
 * Trivy Operator Module
 * Deploys Trivy Operator for security scanning within the cluster.
 */

# Create namespace if needed (optional, can be created elsewhere)
resource "kubernetes_namespace" "trivy_ns" {
  metadata {
    name = var.trivy_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      # Apply PSS label if managed here, otherwise ensure it's applied elsewhere
      # "pod-security.kubernetes.io/enforce" = "restricted"
      # "pod-security.kubernetes.io/audit"   = "restricted"
      # "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

# Create IAM Role and Service Account for Trivy Operator (IRSA)
# Note: Trivy Operator primarily needs Kubernetes RBAC (handled by chart)
# This IRSA role is minimal, primarily for potential future AWS integrations (like ECR scanning FROM the operator)
# or if specific chart features require it. Add specific AWS policies here if needed.
resource "aws_iam_role" "trivy_operator" {
  count = 1 # Always create the role for annotation consistency
  name  = "${var.cluster_name}-trivy-operator-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.cluster_oidc_provider_arn, "/^arn:aws:iam::[0-9]*:oidc-provider\\//", "")}:sub": "system:serviceaccount:${var.trivy_namespace}:${var.trivy_service_account_name}"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# No default policy attachment - add policies here if specific AWS access is required by Trivy Operator config

# Deploy Trivy Operator Helm chart
resource "helm_release" "trivy_operator" {
  name       = "trivy-operator"
  repository = "https://aquasecurity.github.io/helm-charts/"
  chart      = "trivy-operator"
  version    = var.trivy_helm_chart_version
  namespace  = kubernetes_namespace.trivy_ns.metadata[0].name # Reference TF namespace
  create_namespace = false # Helm should NOT create the namespace

  values = [
    templatefile("${path.module}/templates/values.yaml", {
      iam_role_arn         = aws_iam_role.trivy_operator[0].arn
      service_account_name = var.trivy_service_account_name
      node_selector        = jsonencode(var.management_node_selector)
      tolerations          = jsonencode(var.management_tolerations)
    })
  ]

  # Ensure namespace and role exist first
  depends_on = [
    kubernetes_namespace.trivy_ns,
    aws_iam_role.trivy_operator
  ]
} 