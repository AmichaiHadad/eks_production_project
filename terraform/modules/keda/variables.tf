variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
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

variable "app_deployment_name" {
  description = "Name of the application deployment to scale"
  type        = string
}

variable "app_namespace" {
  description = "Namespace of the application to scale"
  type        = string
}

variable "prometheus_url" {
  description = "URL of the Prometheus server for metrics"
  type        = string
}

variable "keda_chart_version" {
  description = "Version of the KEDA Helm chart"
  type        = string
  default     = "2.16.0"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}