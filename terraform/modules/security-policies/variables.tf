# Variables for the security-policies module

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "enabled" {
  description = "Flag to enable/disable the Polaris deployment."
  type        = bool
  default     = true
}

variable "polaris_helm_chart_version" {
  description = "Version of the Polaris Helm chart to deploy."
  type        = string
}

variable "eks_cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "cluster_endpoint" {
  description = "API endpoint of the EKS cluster"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Certificate authority data for the EKS cluster"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster (e.g., https://oidc.eks.region.amazonaws.com/id/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx). Remove https:// prefix."
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID where the EKS cluster resides."
  type        = string
}

# --- Existing variables ---
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "data_namespace" {
  description = "Namespace commonly used for data services (e.g., MySQL)."
  type        = string
  default     = "data"
}

variable "argocd_namespace" {
  description = "Namespace where Argo CD resides."
  type        = string
  default     = "argocd"
}