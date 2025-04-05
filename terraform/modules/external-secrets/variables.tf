variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
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

variable "secret_prefix" {
  description = "Prefix for secrets in AWS Secrets Manager"
  type        = string
  default     = "eks-blizzard"
}

variable "parameter_prefix" {
  description = "Prefix for parameters in AWS SSM Parameter Store"
  type        = string
  default     = "eks-blizzard"
}

variable "chart_version" {
  description = "Version of the External Secrets Helm chart"
  type        = string
  default     = "0.9.9"
}

variable "mysql_password" {
  description = "MySQL password (only used if generate_random_password is false)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "generate_random_password" {
  description = "Whether to generate a random password for MySQL"
  type        = bool
  default     = true
}

variable "weather_api_key" {
  description = "Weather API key"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}