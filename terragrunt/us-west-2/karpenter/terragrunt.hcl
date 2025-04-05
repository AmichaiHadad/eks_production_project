include {
  path = find_in_parent_folders()
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
  source = "${get_parent_terragrunt_dir()}/../terraform/modules/karpenter"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.region
}

inputs = {
  cluster_name       = dependency.eks.outputs.cluster_name
  cluster_arn        = dependency.eks.outputs.cluster_arn
  cluster_endpoint   = dependency.eks.outputs.cluster_endpoint
  oidc_provider      = dependency.eks.outputs.oidc_provider
  oidc_provider_arn  = dependency.eks.outputs.oidc_provider_arn
  node_iam_role_arn  = dependency.node_groups.outputs.services_node_group_role_arn
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  security_group_ids = [dependency.eks.outputs.cluster_security_group_id]
  region             = local.region
  karpenter_chart_version = "1.0.0"
  
  tags = {
    Environment = "production"
    Region      = local.region
    ManagedBy   = "terragrunt"
    Project     = "eks-blizzard"
  }
}