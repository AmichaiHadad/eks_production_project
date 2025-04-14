# VPC and networking configuration for us-east-1 region

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
  source = "../../../terraform/modules/vpc"
}

# Dependencies
dependencies {
  paths = []
}

# Inputs to the VPC module
inputs = {
  aws_region      = include.region.locals.aws_region
  vpc_name        = "vpc-${include.region.locals.cluster_name}"
  vpc_cidr        = include.region.locals.vpc_cidr
  azs             = include.region.locals.azs
  private_subnet_cidrs = include.region.locals.private_subnet_cidrs
  public_subnet_cidrs  = include.region.locals.public_subnet_cidrs
  
  # Additional tags for the subnets
  private_subnet_tags = {
    "kubernetes.io/cluster/${include.region.locals.cluster_name}" = "shared"
  }
  
  public_subnet_tags = {
    "kubernetes.io/cluster/${include.region.locals.cluster_name}" = "shared"
  }
  
  # EKS cluster name for tagging
  eks_cluster_name = include.region.locals.cluster_name
  
  # Common tags
  tags = {
    Name        = "vpc-${include.region.locals.cluster_name}"
    Region      = include.region.locals.aws_region
    Environment = "production"
  }
}