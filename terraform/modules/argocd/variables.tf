variable "cluster_name" {
  description = "Name of the EKS cluster"
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
  default     = "5.51.4" # Compatible with Argo CD 2.14+
}

variable "ingress_enabled" {
  description = "Enable ingress for Argo CD server"
  type        = bool
  default     = true
}

variable "ingress_host" {
  description = "Hostname for the Argo CD ingress"
  type        = string
  default     = "argocd.example.com"
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
  default     = "1.6.2"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "dns_managed" {
  description = "Whether to manage DNS records for ArgoCD"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The root domain name for creating ArgoCD DNS records (e.g., example.com)"
  type        = string
  default     = ""
}