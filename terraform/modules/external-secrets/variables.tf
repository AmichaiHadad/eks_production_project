variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
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
  default     = "0.15.1"
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

variable "mysql_app_user" {
  description = "MySQL application username"
  type        = string
  default     = "app_user"
}

variable "mysql_app_database" {
  description = "MySQL application database name"
  type        = string
  default     = "app_db"
}

variable "weather_api_key" {
  description = "Weather API key"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for Alertmanager notifications"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# Variable for the target namespace for Kubernetes secrets
variable "data_namespace" {
  description = "Namespace where the MySQL Kubernetes secrets should be created."
  type        = string
  default     = "data"
}

# Variable for the name of the Kubernetes secret for MySQL root
variable "k8s_root_secret_name" {
  description = "Name of the Kubernetes secret to store the MySQL root password."
  type        = string
  default     = "mysql-root-credential"
}

# Variable for the name of the Kubernetes secret for MySQL app user
variable "k8s_app_secret_name" {
  description = "Name of the Kubernetes secret to store the MySQL app user password."
  type        = string
  default     = "mysql-app-credential"
}

# Variables for Kubernetes provider configuration (adjust if needed, often configured globally)
variable "kubeconfig_path" {
  description = "Path to the kubeconfig file (if not using default). Optional."
  type        = string
  default     = null
}

variable "kubeconfig_context" {
  description = "Context to use within the kubeconfig file (if not using default). Optional."
  type        = string
  default     = null
}

# Variable for the target namespace for Grafana K8s secret
variable "monitoring_namespace" {
  description = "Namespace where the Grafana Kubernetes secret should be created."
  type        = string
  default     = "monitoring" # Default to a common monitoring namespace
}

# Variable for the name of the Kubernetes secret for Grafana admin
variable "k8s_grafana_secret_name" {
  description = "Name of the Kubernetes secret to store the Grafana admin credentials."
  type        = string
  default     = "grafana-admin-credentials"
}

# Variable for the name of the Kubernetes secret for Slack webhook
variable "k8s_slack_secret_name" {
  description = "Name of the Kubernetes secret to store the Slack webhook URL."
  type        = string
  default     = "alertmanager-slack-webhook" # Default name expected by kube-prometheus-stack
}

# Variable for the target namespace for App K8s secrets
variable "app_namespace" {
  description = "Namespace where the application Kubernetes secrets should be created."
  type        = string
  default     = "app"
}

# Variable for the name of the Kubernetes secret for Weather API key
variable "k8s_weather_secret_name" {
  description = "Name of the Kubernetes secret to store the Weather API key."
  type        = string
  default     = "weather-api-key"
}

# Variable for the name of the Kubernetes secret for MySQL App User (for App)
variable "k8s_app_mysql_secret_name" {
  description = "Name of the Kubernetes secret to store the MySQL app user credentials for the application."
  type        = string
  default     = "mysql-app-credentials" # Match the one created for MySQL itself
}