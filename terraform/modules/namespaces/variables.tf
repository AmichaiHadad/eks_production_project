variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "cluster_endpoint" {
  description = "The endpoint for the EKS cluster's API server."
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster."
  type        = string
  sensitive   = true # Mark as sensitive if appropriate
}

# Add other variables if needed, like tags or region
variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "AWS region for the cluster"
  type        = string
} 