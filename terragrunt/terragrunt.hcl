# Root terragrunt.hcl configuration
# This file defines common settings for all terragrunt configurations

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "eks-blizzard-terragrunt-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "eks-blizzard-terragrunt-locks"
  }
}

# Generate AWS provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  default_tags {
    tags = {
      Project     = "${local.project_name}"
      Environment = "${local.environment}"
      ManagedBy   = "Terraform"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
  required_version = "~> 1.11"
}
EOF
}

# Define global variables
locals {
  # Extract the region from the directory path
  aws_region = element(split("/", path_relative_to_include()), 0)
  
  # Common project settings
  project_name = "eks-project"
  environment  = "production"
  domain_name  = "blizzard.co.il"
  
  # Common tags for all resources
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}

# Define global inputs that can be referenced by all terraform modules
inputs = {
  project_name = local.project_name
  environment  = local.environment
  aws_region   = local.aws_region
  domain_name  = local.domain_name
  tags         = local.common_tags
}