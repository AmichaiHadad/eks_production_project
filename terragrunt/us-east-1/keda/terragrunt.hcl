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

# Dependencies: Ensure KEDA runs after Karpenter.
dependencies {
  paths = ["../karpenter"]
}

terraform {
  # Use a direct relative path for robustness
  source = "../../../terraform/modules/keda"
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
  oidc_provider = dependency.eks.outputs.oidc_provider_url
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  app_deployment_name = "weather-app"  # This should match your application deployment name
  app_namespace = "app"  # This should match your application namespace
  prometheus_url = "http://prometheus-server.monitoring:9090"  # This should match your Prometheus server URL
}