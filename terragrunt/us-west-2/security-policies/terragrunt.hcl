include {
  path = find_in_parent_folders()
  expose = true
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

dependency "eks" {
  config_path = "../eks"
}

# Dependencies: Ensure Security Policies run after Network Policies.
# EKS dependency is implicit because we reference its outputs.
dependencies {
  paths = ["../network-policies"]
}

terraform {
  source = "${get_repo_root()}//terraform/modules/security-policies"
}

locals {
  # No need for region_vars or root_dir here if inherited
}

# Top-level inputs - Inherited from root/region includes and fetched from dependencies
inputs = {
  # Inherited from root/region
  aws_region                          = include.region.locals.aws_region
  tags                                = include.region.locals.tags
  eks_cluster_name                    = dependency.eks.outputs.cluster_name
  cluster_endpoint                    = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data  = dependency.eks.outputs.cluster_certificate_authority_data

  # Fetch Account ID from EKS dependency
  aws_account_id                      = dependency.eks.outputs.account_id

  # Fetch OIDC URL from EKS dependency output (using correct output name) and process it
  cluster_oidc_issuer_url             = replace(dependency.eks.outputs.oidc_provider_url, "https://", "")

  # Other module-specific inputs
  polaris_helm_chart_version = "5.18.0"
}