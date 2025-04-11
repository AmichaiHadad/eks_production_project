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