variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the EKS cluster is deployed"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Certificate authority data for the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Argo CD"
  type        = string
  default     = "argocd"
}

variable "argocd_helm_chart_version" {
  description = "Version of the Argo CD Helm chart to use"
  type        = string
  default     = "7.8.23" # Compatible with Argo CD 2.14+
}

variable "ingress_enabled" {
  description = "Enable ingress for Argo CD server"
  type        = bool
  default     = true
}

variable "ingress_host" {
  description = "Hostname for the Argo CD ingress"
  type        = string
}

variable "ingress_tls_secret" {
  description = "Name of the TLS secret for the Argo CD ingress"
  type        = string
  default     = ""
}

variable "service_type" {
  description = "Service type for Argo CD server"
  type        = string
  default     = "ClusterIP"
}

variable "node_selector" {
  description = "Node selector for Argo CD pods"
  type        = map(string)
  default     = {
    "node-role" = "management"
  }
}

variable "toleration_key" {
  description = "Toleration key for management nodes"
  type        = string
  default     = "management"
}

variable "toleration_value" {
  description = "Toleration value for management nodes (must be a string)"
  type        = string
  default     = "true"
}

variable "toleration_effect" {
  description = "Toleration effect for management nodes"
  type        = string
  default     = "NoSchedule"
}

variable "application_sets" {
  description = "List of ApplicationSets to create"
  type        = list(object({
    name            = string
    repo_url        = string
    path            = string
    target_revision = string
    target_namespace = string
    auto_sync       = bool
    self_heal       = bool
    values          = optional(map(string), {})
  }))
  default     = []
}

variable "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "lb_controller_helm_chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart to use"
  type        = string
  default     = "1.12.0"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}