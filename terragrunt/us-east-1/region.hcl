# Region-specific variables for us-east-1

locals {
  # Region and AZ configuration
  aws_region  = "us-east-1"
  azs         = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  # VPC and networking configuration
  vpc_cidr            = "10.10.0.0/16"
  private_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  public_subnet_cidrs  = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  
  # EKS Configuration
  cluster_name = "eks-blizzard-us-east-1"
  kubernetes_version = "1.32"
  kms_key_id = "7032bea8-c4ca-4fd7-9f9e-1a19fd6fb72a"
  
  # Other regional settings
  tags = {
    Environment = "production"
    Region = "us-east-1"
    Project = "eks-blizzard"
  }
  
  # DNS and domain configuration
  subdomain = "us-east-1"
  domain_name = "blizzard.co.il"
  
  # TLS certificate for HTTPS
  acm_certificate_arn = "arn:aws:acm:us-east-1:163459217187:certificate/4ff90f30-64f8-40e1-b1b3-8f13d5fac876"

}