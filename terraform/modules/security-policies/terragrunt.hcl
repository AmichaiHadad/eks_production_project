include {
  path = find_in_parent_folders()
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

dependency "eks" {
  config_path = "../eks"
}

# Dependencies: Ensure Security Policies are applied after Network Policies.
dependencies {
  paths = ["../network-policies"]
}

terraform {
  source = "../../../terraform/modules/security-policies"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
}

# Top-level inputs
inputs = {
  aws_region   = include.region.locals.aws_region
  tags         = include.region.locals.tags
  polaris_helm_chart_version = "5.18.0" # Updated based on latest available chart version
  eks_cluster_name = dependency.eks.outputs.cluster_name
}