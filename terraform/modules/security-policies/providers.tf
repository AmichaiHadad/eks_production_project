# Configure AWS Provider - required for other operations
provider "aws" {
  region = var.aws_region
}

# Configure Kubernetes provider for EKS
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  # Assume AWS CLI is configured for authentication
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.aws_region]
    command     = "aws"
  }
}

# Configure Helm provider for EKS
provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    # Assume AWS CLI is configured for authentication
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.aws_region]
      command     = "aws"
    }
  }
}

# Configure kubectl provider for manifests (optional for this module currently, but good practice)
provider "kubectl" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  load_config_file       = false
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.aws_region]
  }
} 