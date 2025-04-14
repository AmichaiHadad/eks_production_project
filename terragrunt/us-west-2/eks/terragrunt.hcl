# EKS cluster configuration for us-east-1 region

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
  source = "../../../terraform/modules/eks-cluster"
}

# Dependencies
dependencies {
  paths = ["../networking"]
}

dependency "vpc" {
  config_path = "../networking"
}

# Inputs to the EKS cluster module
inputs = {
  aws_region              = include.region.locals.aws_region
  cluster_name            = include.region.locals.cluster_name
  kubernetes_version      = include.region.locals.kubernetes_version
  subnet_ids              = dependency.vpc.outputs.private_subnets
  cluster_security_group_id = dependency.vpc.outputs.cluster_security_group_id
  
  # Common tags
  tags = {
    Name        = include.region.locals.cluster_name
    Region      = include.region.locals.aws_region
    Environment = "production"
  }
}