include {
  path = find_in_parent_folders()
}

dependency "eks" {
  config_path = "../eks"
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../terraform/modules/external-secrets"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.region
  account_id  = get_aws_account_id()
}

inputs = {
  cluster_name     = dependency.eks.outputs.cluster_name
  region           = local.region
  account_id       = local.account_id
  oidc_provider    = dependency.eks.outputs.oidc_provider
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  
  # Customize these values as needed
  secret_prefix    = "eks-blizzard-${local.region}"
  parameter_prefix = "eks-blizzard/${local.region}"
  chart_version    = "0.9.9"
  
  # In a real scenario, these would be securely passed via environment variables
  # or another secure method, not hardcoded
  generate_random_password = true
  weather_api_key = "placeholder-api-key"
  
  tags = {
    Environment = "production"
    Region      = local.region
    ManagedBy   = "terragrunt"
    Project     = "eks-blizzard"
  }
}