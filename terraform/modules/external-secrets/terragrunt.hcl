include {
  path = find_in_parent_folders()
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

# Dependencies: Ensure external-secrets runs after EKS addons are set up.
dependencies {
  paths = ["../eks-addons"]
}

dependency "eks" {
  config_path = "../eks"
}

terraform {
  source = "../../../terraform/modules/external-secrets"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
  account_id  = get_aws_account_id()
}

# Top-level inputs
inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  aws_region   = include.region.locals.aws_region
  region       = include.region.locals.aws_region
  tags         = include.region.locals.tags
  cluster_oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  account_id   = local.account_id
  oidc_provider = dependency.eks.outputs.oidc_provider_url
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
}