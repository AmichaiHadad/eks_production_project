# Defines required provider versions for the namespaces module

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
    # Explicitly require gavinbunney/kubectl even if not directly used
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
  }
  required_version = "~> 1.11"
} 