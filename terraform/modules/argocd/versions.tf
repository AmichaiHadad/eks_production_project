# Defines required provider versions for the argocd module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.94"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    # Explicitly require gavinbunney/kubectl
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    # Add time provider for wait_after_ingress resource
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
  required_version = "~> 1.11"
} 