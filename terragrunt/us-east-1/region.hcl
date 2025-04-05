# Region-specific variables for us-east-1

locals {
  # Region and AZ configuration
  aws_region  = "us-east-1"
  azs         = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  # VPC and networking configuration
  vpc_cidr            = "10.10.0.0/16"
  private_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  public_subnet_cidrs  = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  
  # EKS cluster configuration
  eks_cluster_name    = "eks-blizzard-us-east-1"
  kubernetes_version  = "1.27"
  
  # DNS and domain configuration
  subdomain = "us-east-1"
  domain_name = "blizzard.co.il"
}