# Defines required provider versions for the network-policies module

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
    # Explicitly require gavinbunney/kubectl
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
  }
  required_version = "~> 1.11"
} 