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
  kubernetes_version  = "1.32"
  kms_key_id = "7032bea8-c4ca-4fd7-9f9e-1a19fd6fb72a"
  
  # DNS and domain configuration
  subdomain = "us-west-2"
  domain_name = "blizzard.co.il"
}

 # Other regional settings
  tags = {
    Environment = "production"
    Region = "us-west-2"
    Project = "eks-blizzard"
  }

  # TLS certificate for HTTPS
  acm_certificate_arn = "arn:aws:acm:us-east-1:163459217187:certificate/4ff90f30-64f8-40e1-b1b3-8f13d5fac876"