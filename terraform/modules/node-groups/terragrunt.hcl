# Node Groups configuration for us-east-1 region

# Include the root terragrunt.hcl configuration
include "root" {
  path = find_in_parent_folders()
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

# Terraform source
terraform {
  source = "../../../terraform/modules/node-groups"
}

# Dependencies
dependencies {
  paths = ["../networking", "../eks"]
}

dependency "vpc" {
  config_path = "../networking"
}

dependency "eks" {
  config_path = "../eks"
}

# Inputs to the node groups module
inputs = {
  aws_region   = include.region.locals.aws_region
  cluster_name = dependency.eks.outputs.cluster_name
  subnet_ids   = dependency.vpc.outputs.private_subnets
  
  # Monitoring node group configuration
  monitoring_instance_types = ["t3.large"]
  monitoring_desired_size   = 2
  monitoring_min_size       = 1
  monitoring_max_size       = 3
  
  # Management node group configuration
  management_instance_types = ["t3.medium"]
  management_desired_size   = 2
  management_min_size       = 1
  management_max_size       = 3
  
  # Services node group configuration
  services_instance_types   = ["m5.large"]
  services_desired_size     = 2
  services_min_size         = 2
  services_max_size         = 5
  
  # Data node group configuration
  data_instance_types       = ["r5.xlarge"]
  data_desired_size         = 3
  data_min_size             = 3
  data_max_size             = 5
  
  # Common tags
  tags = {
    Region      = include.region.locals.aws_region
    Environment = "production"
  }
}