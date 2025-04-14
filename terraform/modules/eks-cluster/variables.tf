variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "subnet_ids" {
  description = "List of subnet IDs to use for the EKS cluster (private subnets)"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Security group ID to use for the EKS cluster"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cni_version" {
  description = "Version of the VPC CNI add-on to use"
  type        = string
  default     = ""
}

variable "coredns_version" {
  description = "Version of the CoreDNS add-on to use"
  type        = string
  default     = ""
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy add-on to use"
  type        = string
  default     = ""
}