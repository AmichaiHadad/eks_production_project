output "vpc_cni_addon_id" {
  description = "ID of the VPC CNI add-on"
  value       = aws_eks_addon.vpc_cni.id
}

output "vpc_cni_version" {
  description = "Installed version of the VPC CNI add-on"
  value       = aws_eks_addon.vpc_cni.addon_version
}

output "vpc_cni_irsa_role_arn" {
  description = "ARN of the IAM role used by the VPC CNI addon"
  value       = var.create_vpc_cni_irsa ? aws_iam_role.vpc_cni[0].arn : null
}

output "coredns_addon_id" {
  description = "ID of the CoreDNS add-on"
  value       = aws_eks_addon.coredns.id
}

output "coredns_version" {
  description = "Installed version of the CoreDNS add-on"
  value       = aws_eks_addon.coredns.addon_version
}

output "kube_proxy_addon_id" {
  description = "ID of the kube-proxy add-on"
  value       = aws_eks_addon.kube_proxy.id
}

output "kube_proxy_version" {
  description = "Installed version of the kube-proxy add-on"
  value       = aws_eks_addon.kube_proxy.addon_version
}

output "ebs_csi_driver_addon_id" {
  description = "ID of the AWS EBS CSI Driver add-on"
  value       = aws_eks_addon.ebs_csi_driver.id
}

output "ebs_csi_driver_version" {
  description = "Installed version of the AWS EBS CSI Driver add-on"
  value       = aws_eks_addon.ebs_csi_driver.addon_version
}

output "ebs_csi_driver_irsa_role_arn" {
  description = "ARN of the IAM role used by the AWS EBS CSI Driver addon"
  value       = var.create_ebs_csi_driver_irsa ? aws_iam_role.ebs_csi_driver[0].arn : null
}

output "route53_dns_manager_irsa_role_arn" {
  description = "ARN of the IAM role for Route53 DNS Manager"
  value       = var.create_route53_dns_manager_irsa ? aws_iam_role.route53_dns_manager[0].arn : null
}

output "route53_dns_manager_policy_arn" {
  description = "ARN of the IAM policy for Route53 DNS Manager"
  value       = var.create_route53_dns_manager_irsa ? aws_iam_policy.route53_dns_manager[0].arn : null
}

output "external_dns_helm_release_status" {
  description = "Status of the ExternalDNS Helm release"
  value       = var.create_route53_dns_manager_irsa ? helm_release.external_dns[0].status : "disabled"
}