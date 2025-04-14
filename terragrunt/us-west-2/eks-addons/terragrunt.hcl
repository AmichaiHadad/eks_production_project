# EKS Addons configuration for us-east-1 region

# Include the root terragrunt.hcl configuration
include {
  path = find_in_parent_folders()
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

# Terraform source
terraform {
  source = "../../../terraform/modules/eks-addons"
}

# Dependencies - critical to ensure addons are installed after node groups
dependencies {
  paths = ["../networking", "../eks", "../node-groups"]
}

dependency "eks" {
  config_path = "../eks"
}

dependency "node_groups" {
  config_path = "../node-groups"
}

# Generate provider configuration dynamically
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${include.region.locals.aws_region}"
  default_tags {
    tags = ${jsonencode(include.region.locals.tags)}
  }
}

provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = "${dependency.eks.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
      command     = "aws"
    }
  }
}

# Explicitly configure the gavinbunney/kubectl provider with an alias
provider "kubectl" {
  alias                  = "gavinbunney"
  apply_retry_count      = 5
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
    command     = "aws"
  }
  load_config_file = false
}
EOF
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
}

# Top-level inputs
inputs = {
  # Pass required cluster information for provider configuration
  cluster_name     = dependency.eks.outputs.cluster_name
  cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  cluster_ca_cert  = dependency.eks.outputs.cluster_certificate_authority_data
  aws_region       = include.region.locals.aws_region
  tags             = include.region.locals.tags
  cluster_oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  
  # Enable External DNS
  create_route53_dns_manager_irsa = true
  external_dns_domain_filter = include.region.locals.domain_name
  external_dns_txt_owner_id = include.region.locals.cluster_name
  route53_dns_manager_namespace = "kube-system"
  route53_dns_manager_service_account = "external-dns"
}