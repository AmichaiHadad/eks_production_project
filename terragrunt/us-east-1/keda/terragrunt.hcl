include {
  path = find_in_parent_folders()
}

dependency "eks" {
  config_path = "../eks"
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../terraform/modules/keda"
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
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
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
      }
    }

    provider "helm" {
      kubernetes {
        host                   = "${dependency.eks.outputs.cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
        exec {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
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
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
      }
    }
  EOF
}

inputs = {
  cluster_name       = dependency.eks.outputs.cluster_name
  oidc_provider      = dependency.eks.outputs.oidc_provider_url
  oidc_provider_arn  = dependency.eks.outputs.oidc_provider_arn
  app_deployment_name = "app"
  app_namespace      = "default"
  prometheus_url     = "http://prometheus-server.monitoring.svc.cluster.local:9090"
  keda_chart_version = "2.16.0"
  
  tags = {
    Environment = "production"
    Region      = local.region
    ManagedBy   = "terragrunt"
    Project     = "eks-blizzard"
  }
}