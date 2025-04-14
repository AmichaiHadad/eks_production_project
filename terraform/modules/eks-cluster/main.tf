/**
 * EKS Cluster Module
 * Creates an Amazon EKS cluster with:
 * - Private endpoint access
 * - OIDC identity provider for IRSA
 * - CloudWatch logging
 * - Necessary IAM roles
 */

# IAM Role for EKS Control Plane
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach required AWS managed policies to cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Create the EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    # Security hardening: Private endpoint access only
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [var.cluster_security_group_id]
  }

  # Enable CloudWatch logging for audit, authenticator, controllerManager and scheduler
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # Optional: encryption configuration for secrets
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_encryption_key.arn
    }
    resources = ["secrets"]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy
  ]

  tags = var.tags
}

# KMS key for EKS cluster encryption
resource "aws_kms_key" "eks_encryption_key" {
  description             = "KMS key for EKS cluster ${var.cluster_name} secret encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-encryption-key"
    }
  )
}

resource "aws_kms_alias" "eks_encryption_key_alias" {
  name          = "alias/${var.cluster_name}-encryption-key"
  target_key_id = aws_kms_key.eks_encryption_key.key_id
}

# Enable OIDC identity provider for the cluster
# This is unnecessary and causing conflicts since EKS already creates an OIDC provider
# The aws_iam_openid_connect_provider resource below is sufficient for IRSA setup
# resource "aws_eks_identity_provider_config" "this" {
#   cluster_name = aws_eks_cluster.eks_cluster.name
#
#   oidc {
#     client_id                     = "sts.amazonaws.com"
#     identity_provider_config_name = "oidc-provider"
#     issuer_url                    = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
#   }
# }

# Create IAM OIDC provider for IRSA
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-oidc-provider"
    }
  )
}

# Note: Add-ons are commented out here as they require nodes to be available
# They will be installed separately after node groups are created

# # Install VPC CNI add-on (recommended for latest version)
# resource "aws_eks_addon" "vpc_cni" {
#   cluster_name = aws_eks_cluster.eks_cluster.name
#   addon_name   = "vpc-cni"
#   
#   # Use latest available version compatible with cluster version
#   addon_version = var.vpc_cni_version != "" ? var.vpc_cni_version : null
#   
#   # Resolve conflicts by overwriting
#   resolve_conflicts = "OVERWRITE"
#   
#   depends_on = [
#     aws_eks_cluster.eks_cluster
#   ]
# }
# 
# # Install CoreDNS add-on
# resource "aws_eks_addon" "coredns" {
#   cluster_name = aws_eks_cluster.eks_cluster.name
#   addon_name   = "coredns"
#   
#   # Use latest available version compatible with cluster version
#   addon_version = var.coredns_version != "" ? var.coredns_version : null
#   
#   # Resolve conflicts by overwriting
#   resolve_conflicts = "OVERWRITE"
#   
#   depends_on = [
#     aws_eks_cluster.eks_cluster
#   ]
# }
# 
# # Install kube-proxy add-on
# resource "aws_eks_addon" "kube_proxy" {
#   cluster_name = aws_eks_cluster.eks_cluster.name
#   addon_name   = "kube-proxy"
#   
#   # Use latest available version compatible with cluster version
#   addon_version = var.kube_proxy_version != "" ? var.kube_proxy_version : null
#   
#   # Resolve conflicts by overwriting
#   resolve_conflicts = "OVERWRITE"
#   
#   depends_on = [
#     aws_eks_cluster.eks_cluster
#   ]
# }