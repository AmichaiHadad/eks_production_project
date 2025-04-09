include {
  path = find_in_parent_folders()
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
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

terraform {
  source = "../../../terraform/modules/karpenter"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
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

inputs = {
  cluster_name       = dependency.eks.outputs.cluster_name
  cluster_arn        = dependency.eks.outputs.cluster_arn
  cluster_endpoint   = dependency.eks.outputs.cluster_endpoint
  oidc_provider      = dependency.eks.outputs.oidc_provider_url
  oidc_provider_arn  = dependency.eks.outputs.oidc_provider_arn
  node_iam_role_arn  = dependency.node_groups.outputs.node_role_arn
  node_role_name     = dependency.node_groups.outputs.node_role_name
  private_subnet_ids = dependency.vpc.outputs.private_subnets
  security_group_ids = [dependency.eks.outputs.cluster_security_group_id]
  region             = local.region
  karpenter_chart_version = "1.3.3"
  
  tags = {
    Environment = "production"
    Region      = local.region
    ManagedBy   = "terragrunt"
    Project     = "eks-blizzard"
  }
}