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

dependency "node_groups" {
  config_path = "../node-groups"
}

dependency "vpc" {
  config_path = "../networking"
}

# Dependencies: Ensure Karpenter runs after ArgoCD is ready.
dependencies {
  paths = ["../argocd"]
}

terraform {
  source = "../../../terraform/modules/karpenter"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
}

# Top-level inputs
inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  cluster_arn = dependency.eks.outputs.cluster_arn
  cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  aws_region   = include.region.locals.aws_region
  region       = include.region.locals.aws_region
  tags         = include.region.locals.tags
  oidc_provider = dependency.eks.outputs.oidc_provider_url
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  node_iam_role_arn = dependency.node_groups.outputs.node_role_arn
  node_role_name = dependency.node_groups.outputs.node_role_name
  private_subnet_ids = dependency.vpc.outputs.private_subnets
  security_group_ids = [dependency.eks.outputs.cluster_security_group_id]
}