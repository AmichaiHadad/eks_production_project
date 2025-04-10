# EKS Addons configuration for us-west-2 region

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
  source = "../../../terraform/modules/eks-addons"
}

# Dependencies - critical to ensure addons are installed after node groups
dependencies {
  paths = ["../networking", "../eks", "../node-groups"]
}

dependency "eks" {
  config_path = "../eks"
}

dependency "node_groups" {
  config_path = "../node-groups"
}

# Inputs to the EKS Addons module
inputs = {
  # Required parameter - cluster name from the EKS module output
  cluster_name = dependency.eks.outputs.cluster_name
  
  # OIDC provider ARN for IRSA
  cluster_oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  
  # Enable IRSA for VPC CNI and EBS CSI Driver
  create_vpc_cni_irsa = true
  create_ebs_csi_driver_irsa = true
  
  # Enable IRSA for Route53 DNS Manager
  create_route53_dns_manager_irsa = true
  route53_dns_manager_namespace = "kube-system"
  route53_dns_manager_service_account = "external-dns"
  
  # Optional parameters - if specific versions are needed
  vpc_cni_version    = ""  # Leave empty for latest version
  coredns_version    = ""  # Leave empty for latest version
  kube_proxy_version = ""  # Leave empty for latest version
  ebs_csi_driver_version = ""  # Leave empty for latest version
  
  # Common tags
  tags = {
    Region      = include.region.locals.aws_region
    Environment = "production"
  }
}