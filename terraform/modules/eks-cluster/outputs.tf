output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.eks_cluster.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.eks_cluster.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks_oidc.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider for IRSA"
  value       = replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster"
  value       = aws_iam_role.eks_cluster_role.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.arn
}

output "encryption_key_arn" {
  description = "ARN of the KMS key used for EKS cluster encryption"
  value       = aws_kms_key.eks_encryption_key.arn
}

# Addon outputs are now handled by the eks-addons module
output "vpc_cni_addon_id" {
  description = "ID of the VPC CNI add-on (now moved to eks-addons module)"
  value       = null
}

output "coredns_addon_id" {
  description = "ID of the CoreDNS add-on (now moved to eks-addons module)"
  value       = null
}

output "kube_proxy_addon_id" {
  description = "ID of the kube-proxy add-on (now moved to eks-addons module)"
  value       = null
}

output "account_id" {
  description = "The AWS Account ID where the cluster resides."
  value       = data.aws_caller_identity.current.account_id
} 