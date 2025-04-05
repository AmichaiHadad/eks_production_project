include {
  path = find_in_parent_folders()
}

dependency "eks" {
  config_path = "../eks"
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../terraform/modules/keda"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.region
}

inputs = {
  cluster_name       = dependency.eks.outputs.cluster_name
  oidc_provider      = dependency.eks.outputs.oidc_provider
  oidc_provider_arn  = dependency.eks.outputs.oidc_provider_arn
  app_deployment_name = "app"
  app_namespace      = "default"
  prometheus_url     = "http://prometheus-server.monitoring.svc.cluster.local:9090"
  keda_chart_version = "2.16.0"
  
  tags = {
    Environment = "production"
    Region      = local.region
    ManagedBy   = "terragrunt"
    Project     = "eks-blizzard"
  }
}