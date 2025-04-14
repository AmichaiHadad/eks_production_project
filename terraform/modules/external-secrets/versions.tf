# Defines required provider versions for the external-secrets module

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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.7.1" # Added based on module usage
    }
    null = {
      source = "hashicorp/null"
      version = "~> 3.2.3" # Added based on module usage
    }
  }
  required_version = "~> 1.11"
} 