terraform {
  required_version = ">= 1.11" # Specify a suitable Terraform version constraint

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.94" # Or your specific required version
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36" # Or your specific required version
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17" # Or your specific required version
    }
    kubectl = {
      source  = "gavinbunney/kubectl" # Correct source
      version = "~> 1.19"             # Or your specific required version
    }
  }
} 