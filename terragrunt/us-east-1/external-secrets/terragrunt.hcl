include {
  path = find_in_parent_folders()
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

dependency "eks" {
  config_path = "../eks"
}

terraform {
  source = "../../../terraform/modules/external-secrets"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
  account_id  = get_aws_account_id()
}

# Generate Kubernetes and Helm providers configuration
generate "providers" {
  path      = "kubernetes_providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "kubernetes" {
      host                   = "${dependency.eks.outputs.cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
      }
    }

    provider "helm" {
      kubernetes {
        host                   = "${dependency.eks.outputs.cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
        exec {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
        }
      }
    }

    provider "kubectl" {
      host                   = "${dependency.eks.outputs.cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
      load_config_file       = false
      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
      }
    }
  EOF
}

inputs = {
  cluster_name     = dependency.eks.outputs.cluster_name
  region           = local.region
  account_id       = local.account_id
  oidc_provider    = dependency.eks.outputs.oidc_provider_url
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  
  secret_prefix    = "eks-blizzard-${local.region}"
  parameter_prefix = "eks-blizzard/${local.region}"
  chart_version    = "0.9.9"
  
  generate_random_password = false
  mysql_password = "placeholder-app-password"
  
  weather_api_key = "placeholder-api-key"
  slack_webhook_url = "REPLACE_WITH_ACTUAL_SLACK_WEBHOOK_URL"
  
  tags = {
    Environment = "production"
    Region      = local.region
    ManagedBy   = "terragrunt"
    Project     = "eks-blizzard"
  }
}