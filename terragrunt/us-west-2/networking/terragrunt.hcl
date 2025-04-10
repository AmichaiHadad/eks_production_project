# VPC and networking configuration for us-west-2 region

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
  vpc_name        = "vpc-${include.region.locals.eks_cluster_name}"
  vpc_cidr        = include.region.locals.vpc_cidr
  azs             = include.region.locals.azs
  private_subnet_cidrs = include.region.locals.private_subnet_cidrs
  public_subnet_cidrs  = include.region.locals.public_subnet_cidrs
  
  # Additional tags for the subnets
  private_subnet_tags = {
    "kubernetes.io/cluster/${include.region.locals.eks_cluster_name}" = "shared"
  }
  
  public_subnet_tags = {
    "kubernetes.io/cluster/${include.region.locals.eks_cluster_name}" = "shared"
  }
  
  # EKS cluster name for tagging
  eks_cluster_name = include.region.locals.eks_cluster_name
  
  # Common tags
  tags = {
    Name        = "vpc-${include.region.locals.eks_cluster_name}"
    Region      = include.region.locals.aws_region
    Environment = "production"
  }
}