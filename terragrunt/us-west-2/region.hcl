# Region-specific variables for us-west-2

locals {
  # Region and AZ configuration
  aws_region  = "us-west-2"
  azs         = ["us-west-2a", "us-west-2b", "us-west-2c"]
  
  # VPC and networking configuration
  vpc_cidr            = "10.20.0.0/16"
  private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  public_subnet_cidrs  = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24"]
  
  # EKS cluster configuration
  eks_cluster_name    = "eks-blizzard-us-west-2"
  kubernetes_version  = "1.27"
  
  # DNS and domain configuration
  subdomain = "us-west-2"
  domain_name = "blizzard.co.il"
}