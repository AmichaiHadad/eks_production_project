# Argo CD configuration for us-east-1 region

# Include the root terragrunt.hcl configuration
include "root" {
  path = find_in_parent_folders()
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

# Terraform source
terraform {
  source = "../../../terraform/modules/argocd"
}

# Dependencies
dependencies {
  paths = ["../networking", "../eks", "../node-groups"]
}

dependency "vpc" {
  config_path = "../networking"
}

dependency "eks" {
  config_path = "../eks"
}

dependency "node_groups" {
  config_path = "../node-groups"
}

# Generate Kubernetes and Helm providers configuration
generate "providers" {
  path      = "kubernetes_providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "kubernetes" {
      host                   = "${dependency.eks.outputs.cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
      }
    }

    provider "helm" {
      kubernetes {
        host                   = "${dependency.eks.outputs.cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
        exec {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
        }
      }
    }

    provider "kubectl" {
      host                   = "${dependency.eks.outputs.cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
      load_config_file       = false
      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
      }
    }
  EOF
}

# Inputs to the Argo CD module
inputs = {
  cluster_name            = dependency.eks.outputs.cluster_name
  cluster_oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  
  namespace               = "argocd"
  argocd_helm_chart_version = "5.51.4"  # Compatible with Argo CD 2.14+
  
  # Enable ingress with ACM certificate
  ingress_enabled         = true
  # Use domain_name from global inputs to construct the ingress hostname
  ingress_host            = "argocd.${include.region.locals.domain_name}"
  
  # Use ACM certificate ARN from region config for TLS
  ingress_tls_secret      = include.region.locals.acm_certificate_arn
  
  service_type            = "ClusterIP"
  
  # Schedule on management nodes
  node_selector           = {
    "node-role" = "management"
  }
  toleration_key          = "management"
  toleration_value        = "true"
  toleration_effect       = "NoSchedule"
  
  # ApplicationSets disabled until monitoring stack is deployed
  # Will be re-enabled after Prometheus Operator CRDs are available
  application_sets = []
  
  # Original configuration for reference:
  # application_sets = [
  #   {
  #     name            = "app"
  #     repo_url        = "https://github.com/AmichaiHadad/eks_app_2.git"
  #     path            = "helm-chart/app"
  #     target_revision = "HEAD"
  #     target_namespace = "default"
  #     auto_sync       = true
  #     self_heal       = true
  #   }
  # ]
  
  # Common tags
  tags = {
    Region      = include.region.locals.aws_region
    Environment = "production"
  }
  
  # DNS configuration - Use variables from region.hcl
  domain_name = include.region.locals.domain_name
  dns_managed = true
}