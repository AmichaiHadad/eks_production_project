/**
 * EKS Add-ons Module
 * This module installs essential EKS add-ons after the node groups are ready
 */

# Create IAM role for VPC CNI service account
resource "aws_iam_role" "vpc_cni" {
  count = var.create_vpc_cni_irsa ? 1 : 0
  
  name = "${var.cluster_name}-vpc-cni-irsa"
  
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
            "${replace(var.cluster_oidc_provider_arn, "/^arn:aws:iam::[0-9]*:oidc-provider\\//", "")}:sub": "system:serviceaccount:kube-system:aws-node"
          }
        }
      }
    ]
  })
  
  tags = var.tags
}

# Attach the required IAM policy to the VPC CNI IAM role
resource "aws_iam_role_policy_attachment" "vpc_cni" {
  count = var.create_vpc_cni_irsa ? 1 : 0
  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni[0].name
}

# Install VPC CNI add-on (recommended for latest version)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = var.cluster_name
  addon_name   = "vpc-cni"
  
  # Use latest available version compatible with cluster version
  addon_version = var.vpc_cni_version != "" ? var.vpc_cni_version : null
  
  # Resolve conflicts by overwriting
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  # Configure service account role ARN if IRSA is enabled
  service_account_role_arn = var.create_vpc_cni_irsa ? aws_iam_role.vpc_cni[0].arn : null
  
  tags = var.tags
  
  # Ensure IAM role is created before the addon
  depends_on = [aws_iam_role_policy_attachment.vpc_cni]
}

# Install CoreDNS add-on
resource "aws_eks_addon" "coredns" {
  cluster_name = var.cluster_name
  addon_name   = "coredns"
  
  # Use latest available version compatible with cluster version
  addon_version = var.coredns_version != "" ? var.coredns_version : null
  
  # Resolve conflicts by overwriting
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  tags = var.tags
}

# Install kube-proxy add-on
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = var.cluster_name
  addon_name   = "kube-proxy"
  
  # Use latest available version compatible with cluster version
  addon_version = var.kube_proxy_version != "" ? var.kube_proxy_version : null
  
  # Resolve conflicts by overwriting
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  tags = var.tags
}

# Create IAM role for EBS CSI Driver service account
resource "aws_iam_role" "ebs_csi_driver" {
  count = var.create_ebs_csi_driver_irsa ? 1 : 0
  
  name = "${var.cluster_name}-ebs-csi-driver-irsa"
  
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
            "${replace(var.cluster_oidc_provider_arn, "/^arn:aws:iam::[0-9]*:oidc-provider\\//", "")}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
  
  tags = var.tags
}

# Attach the required IAM policy to the EBS CSI Driver IAM role
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count = var.create_ebs_csi_driver_irsa ? 1 : 0
  
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver[0].name
}

# Install AWS EBS CSI Driver add-on
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = var.cluster_name
  addon_name   = "aws-ebs-csi-driver"
  
  # Use latest available version compatible with cluster version
  addon_version = var.ebs_csi_driver_version != "" ? var.ebs_csi_driver_version : null
  
  # Resolve conflicts by overwriting
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  # Configure service account role ARN if IRSA is enabled
  service_account_role_arn = var.create_ebs_csi_driver_irsa ? aws_iam_role.ebs_csi_driver[0].arn : null
  
  tags = var.tags
  
  # Ensure IAM role is created before the addon
  depends_on = [aws_iam_role_policy_attachment.ebs_csi_driver]
}

# Route53 DNS Manager IAM Role and Policy

# Locals for Route53 DNS Manager policy
locals {
  # Existing policy name to check for
  existing_policy_name = "${var.cluster_name}-route53-dns-policy"
  
  # Policy document for Route53 DNS Manager
  route53_dns_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers"
        ],
        Resource = "*"
      }
    ]
  })
}

# Create Route53 DNS Manager IAM policy
resource "aws_iam_policy" "route53_dns_manager" {
  count = var.create_route53_dns_manager_irsa ? 1 : 0
  
  name        = local.existing_policy_name
  description = "Policy for Route53 DNS Manager service account"
  policy      = local.route53_dns_policy
  
  # Use create_before_destroy for handling policy updates
  lifecycle {
    create_before_destroy = true
  }
}

# Create IAM role for Route53 DNS Manager service account
resource "aws_iam_role" "route53_dns_manager" {
  count = var.create_route53_dns_manager_irsa ? 1 : 0
  
  name = "${var.cluster_name}-route53-dns-manager-irsa"
  
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
            "${replace(var.cluster_oidc_provider_arn, "/^arn:aws:iam::[0-9]*:oidc-provider\\//", "")}:sub": "system:serviceaccount:${var.route53_dns_manager_namespace}:${var.route53_dns_manager_service_account}"
          }
        }
      }
    ]
  })
  
  tags = var.tags
}

# Attach the Route53 DNS Manager policy to the IAM role
resource "aws_iam_role_policy_attachment" "route53_dns_manager" {
  count = var.create_route53_dns_manager_irsa ? 1 : 0
  
  policy_arn = aws_iam_policy.route53_dns_manager[0].arn
  role       = aws_iam_role.route53_dns_manager[0].name
  
  depends_on = [
    aws_iam_policy.route53_dns_manager,
    aws_iam_role.route53_dns_manager
  ]
}