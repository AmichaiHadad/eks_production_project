include {
  path = find_in_parent_folders()
}

dependency "eks" {
  config_path = "../eks"
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../terraform/modules/network-policies"
}

# No inputs needed as the module uses fixed templates