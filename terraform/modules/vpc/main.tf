/**
 * VPC Module for EKS
 * Creates a VPC with:
 * - 3 private subnets (one per AZ)
 * - 3 public subnets (one per AZ)
 * - Internet Gateway for public subnets
 * - NAT Gateway in each AZ's public subnet for private subnet internet access
 * - Associated route tables
 */

# Use the AWS VPC module for best practices
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  # Enable NAT Gateway in each AZ for high availability
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # Enable DNS support for the VPC
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Add tags for Kubernetes to auto-discover subnets
  private_subnet_tags = merge(
    var.private_subnet_tags,
    {
      "kubernetes.io/role/internal-elb" = "1"
      "karpenter.sh/discovery"          = var.eks_cluster_name
    }
  )

  public_subnet_tags = merge(
    var.public_subnet_tags,
    {
      "kubernetes.io/role/elb" = "1"
    }
  )

  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    }
  )
}

# Create security group for cluster internal communication
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.eks_cluster_name}-cluster-sg"
  description = "Security group for EKS cluster internal communication"
  vpc_id      = module.vpc.vpc_id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow intra-cluster communication
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.eks_cluster_name}-cluster-sg"
    }
  )
}