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
  cluster_name                = var.cluster_name
  addon_name                 = "vpc-cni"
  addon_version              = "v1.19.3-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.vpc_cni[0].arn
  tags                       = var.tags

  depends_on = [
    kubectl_manifest.external_dns_netpol,
    kubernetes_service_account_v1.external_dns_sa,
    helm_release.external_dns
  ]
}

# Install CoreDNS add-on
resource "aws_eks_addon" "coredns" {
  cluster_name                = var.cluster_name
  addon_name                 = "coredns"
  addon_version              = "v1.11.4-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                       = var.tags

  depends_on = [
    kubectl_manifest.external_dns_netpol,
    kubernetes_service_account_v1.external_dns_sa,
    helm_release.external_dns
  ]
}

# Install kube-proxy add-on
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = var.cluster_name
  addon_name                 = "kube-proxy"
  addon_version              = "v1.32.0-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                       = var.tags

  depends_on = [
    kubectl_manifest.external_dns_netpol,
    kubernetes_service_account_v1.external_dns_sa,
    helm_release.external_dns
  ]
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
  cluster_name                = var.cluster_name
  addon_name                 = "aws-ebs-csi-driver"
  addon_version              = "v1.41.0-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver[0].arn
  tags                       = var.tags

  depends_on = [
    kubectl_manifest.external_dns_netpol,
    kubernetes_service_account_v1.external_dns_sa,
    helm_release.external_dns
  ]
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

# Create the Kubernetes Service Account if IRSA is enabled
resource "kubernetes_service_account_v1" "external_dns_sa" {
  count = var.create_route53_dns_manager_irsa ? 1 : 0

  metadata {
    name      = var.route53_dns_manager_service_account
    namespace = var.route53_dns_manager_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.route53_dns_manager[0].arn
    }
  }
  automount_service_account_token = true # Ensure token is mounted
}

# Deploy ExternalDNS using Helm chart
resource "helm_release" "external_dns" {
  count = var.create_route53_dns_manager_irsa ? 1 : 0

  name             = "external-dns"
  repository       = "oci://registry-1.docker.io/bitnamicharts" # Use OCI repository
  chart            = "external-dns"                            # Chart name
  namespace        = var.route53_dns_manager_namespace
  version          = var.external_dns_chart_version
  create_namespace = false # Assume namespace exists or is managed elsewhere

  values = [
    <<-EOT
    provider: aws
    aws:
      zoneType: public
      region: ${var.aws_region}
    sources:
      - service
      - ingress
    domainFilters:
      - ${var.external_dns_domain_filter}
    txtOwnerId: ${var.external_dns_txt_owner_id}
    policy: sync
    rbac:
      create: true # Ensure RBAC resources are created for cluster-wide access
      pspEnabled: false # Assuming you are not using PodSecurityPolicy
    serviceAccount:
      create: false # We create it separately via Terraform
      name: ${var.route53_dns_manager_service_account}
      # Annotations are now on the kubernetes_service_account_v1 resource
    # Schedule on management nodes
    nodeSelector:
      node-role: management
    tolerations:
      - key: "management"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
    # Add label for network policy
    podLabels:
      networking/allow-external: "true"
    # Optional: Set resource requests/limits if needed
    # resources:
    #   requests:
    #     cpu: 100m
    #     memory: 128Mi
    #   limits:
    #     cpu: 200m
    #     memory: 256Mi
    EOT
  ]

  depends_on = [
    aws_iam_role_policy_attachment.route53_dns_manager,
    kubernetes_service_account_v1.external_dns_sa # Add dependency on the SA
  ]
}

# Network Policy to allow ExternalDNS egress to API server and DNS
resource "kubectl_manifest" "external_dns_netpol" {
  provider = kubectl.gavinbunney # Explicitly use the aliased provider
  count = var.create_route53_dns_manager_irsa ? 1 : 0 # Only create if ExternalDNS is deployed

  yaml_body = templatefile("${path.module}/templates/external-dns-netpol.yaml", {
    # Pass the correct namespace where ExternalDNS is deployed
    namespace = var.route53_dns_manager_namespace
  })

  # Ensure this applies after the Helm release which creates the pods/labels
  depends_on = [
    helm_release.external_dns
  ]
}

