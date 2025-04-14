variable "aws_region" {
  description = "The AWS region to deploy resources in."
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

variable "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "trivy_namespace" {
  description = "Kubernetes namespace for Trivy Operator"
  type        = string
  default     = "trivy-system"
}

variable "trivy_service_account_name" {
  description = "Name of the Service Account used by Trivy Operator"
  type        = string
  default     = "trivy-operator"
}

variable "trivy_helm_chart_version" {
  description = "Version of the Trivy Operator Helm chart"
  type        = string
  default     = "0.27.0" # Updated default to latest requested version
}

variable "management_node_selector" {
  description = "Node selector for management nodes"
  type        = map(string)
  default     = {
    "node-role" = "management"
  }
}

variable "management_tolerations" {
  description = "Tolerations for management nodes"
  type        = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  default     = [
    {
      key      = "management"
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    }
  ]
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
} 