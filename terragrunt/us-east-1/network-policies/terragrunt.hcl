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

# Dependencies: Ensure Network Policies run after Trivy Operator.
dependencies {
  paths = ["../trivy-operator"]
}

# Optional: Add dependency for security policies if it makes sense
# dependency "security_policies" {
#   config_path = "../security-policies"
#   mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "apply"]
#   mock_outputs = {}
# }

terraform {
  source = "../../../terraform/modules/network-policies"
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

# No inputs needed as the module uses fixed templates