variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster"
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

variable "oidc_provider" {
  description = "OIDC provider for the EKS cluster (without https://)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "node_iam_role_arn" {
  description = "ARN of the IAM role for the EKS node group that Karpenter will manage"
  type        = string
}

variable "node_role_name" {
  description = "Name of the IAM role for the EKS node group that Karpenter will manage"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for node placement"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the nodes"
  type        = list(string)
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "karpenter_chart_version" {
  description = "Version of the Karpenter Helm chart"
  type        = string
  default     = "1.3.2"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}