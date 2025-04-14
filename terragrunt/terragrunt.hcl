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
    region         = "us-east-1" # Should ideally use local.aws_region, but backend config evaluates early
    encrypt        = true
    dynamodb_table = "eks-blizzard-terragrunt-locks"
  }
}

# -------------------------------------

# Define global variables
locals {
  # Extract the region from the directory path
  aws_region = element(split("/", path_relative_to_include()), 0)
  
  # Construct the cluster name dynamically based on the region
  cluster_name = "eks-blizzard-${local.aws_region}" # Assumes naming convention "eks-blizzard-<region>"
  
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
  cluster_name = local.cluster_name

  # Revert to manual input for account ID
  aws_account_id = "YOUR_AWS_ACCOUNT_ID" # Replace with your actual AWS Account ID
}