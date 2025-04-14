variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  type        = string
}

variable "cluster_ca_cert" {
  description = "Certificate authority data for the EKS cluster"
  type        = string
}

variable "vpc_cni_version" {
  description = "Version of the VPC CNI add-on to use (leave empty for latest)"
  type        = string
  default     = ""
}

variable "coredns_version" {
  description = "Version of the CoreDNS add-on to use (leave empty for latest)"
  type        = string
  default     = ""
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy add-on to use (leave empty for latest)"
  type        = string
  default     = ""
}

variable "ebs_csi_driver_version" {
  description = "Version of the AWS EBS CSI Driver add-on to use (leave empty for latest)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "create_vpc_cni_irsa" {
  description = "Whether to create IAM role for VPC CNI service account"
  type        = bool
  default     = true
}

variable "create_ebs_csi_driver_irsa" {
  description = "Whether to create IAM role for EBS CSI Driver service account"
  type        = bool
  default     = true
}

variable "create_route53_dns_manager_irsa" {
  description = "Whether to create IAM role for Route53 DNS Manager service account"
  type        = bool
  default     = false
}

variable "route53_dns_manager_namespace" {
  description = "Kubernetes namespace where the Route53 DNS Manager service account is located"
  type        = string
  default     = "kube-system"
}

variable "route53_dns_manager_service_account" {
  description = "Name of the Kubernetes service account for Route53 DNS Manager"
  type        = string
  default     = "route53-dns-manager"
}

variable "external_dns_chart_version" {
  description = "Helm chart version for ExternalDNS."
  type        = string
  default     = "8.7.11" # Update default to Bitnami chart version
}

variable "external_dns_domain_filter" {
  description = "Domain filter for ExternalDNS (e.g., blizzard.co.il)"
  type        = string
  default     = ""
}

variable "external_dns_txt_owner_id" {
  description = "TXT record owner ID for ExternalDNS"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

# Add other variables as needed