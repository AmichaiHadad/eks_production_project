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

dependency "node_groups" { # Needed for management node definitions
  config_path = "../node-groups"
}

# Dependencies: Ensure Trivy runs after KEDA.
dependencies {
  paths = ["../keda"]
}

terraform {
  source = "../../../terraform/modules/trivy-operator"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
}

# Top-level inputs
inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  aws_region   = include.region.locals.aws_region
  tags         = include.region.locals.tags
  cluster_oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  trivy_namespace = "trivy-system"
  trivy_service_account_name = "trivy-operator"
  trivy_helm_chart_version = "0.27.0"
  management_node_selector = {
    "node-role" = "management"
  }
  management_tolerations = [
    {
      key      = "management"
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    }
  ]
} 