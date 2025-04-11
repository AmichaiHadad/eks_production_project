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

terraform {
  source = "../../../terraform/modules/namespaces"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
}

# Top-level inputs
inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  aws_region   = include.region.locals.aws_region
  tags         = include.region.locals.tags
}
