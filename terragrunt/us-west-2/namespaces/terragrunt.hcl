include {
  path = find_in_parent_folders()
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

# Dependencies: 
# 1. Enforce strict order: Must run AFTER ArgoCD.
# 2. Need EKS outputs for Kubernetes provider configuration.

dependency "eks" {
  config_path = "../eks"
  # We need outputs from eks to configure the k8s provider.
}

# Define other explicit dependencies if needed for inputs (though primary order set by 'dependencies')
/*
dependency "node_groups" {
  config_path = "../node-groups"
}
dependency "eks_addons" {
  config_path = "../eks-addons"
  skip_outputs = true # Assuming no direct outputs needed here
}
*/

# Dependencies
dependencies {
  paths = ["../eks-addons"]
}

terraform {
  source = "../../../terraform/modules/namespaces"
}

# Generate provider configuration dynamically
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
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
EOF
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
}

# Top-level inputs
inputs = {
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  aws_region                         = include.region.locals.aws_region
  # Merge tags
  tags                               = include.region.locals.tags
}
