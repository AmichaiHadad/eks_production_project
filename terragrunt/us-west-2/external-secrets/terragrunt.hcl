include {
  path = find_in_parent_folders()
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

# Dependencies: Ensure external-secrets runs after namespaces are created.
dependencies {
  paths = ["../namespaces"]
}

dependency "eks" {
  config_path = "../eks"
}

terraform {
  source = "../../../terraform/modules/external-secrets"
}

# Generate provider configuration dynamically
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = "${dependency.eks.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
      command     = "aws"
    }
  }
}

provider "kubectl" {
  # alias                  = "kubectl" # Ensure we match the alias if used elsewhere
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.region.locals.aws_region}"]
    command     = "aws"
  }
}
EOF
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
  account_id  = get_aws_account_id()

  # Removed random password generation - will be handled in module
}

# Top-level inputs
inputs = {
  # Cluster details for provider config (now handled by generate block)
  # cluster_name = dependency.eks.outputs.cluster_name
  # cluster_endpoint = dependency.eks.outputs.cluster_endpoint 
  # cluster_ca_cert = dependency.eks.outputs.cluster_certificate_authority_data

  # Other inputs needed by the module
  cluster_name = dependency.eks.outputs.cluster_name # Module might still need name
  aws_region   = include.region.locals.aws_region
  region       = include.region.locals.aws_region
  tags         = include.region.locals.tags
  cluster_oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  account_id   = local.account_id
  oidc_provider = dependency.eks.outputs.oidc_provider_url
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn

  # Removed mysql_root_password input

  # Input for Slack Webhook URL (ensure this is provided securely)
  # Example using an environment variable:
  slack_webhook_url = get_env("TF_VAR_slack_webhook_url", "")
  # Or directly (less secure, ensure value is set):
  # slack_webhook_url = "YOUR_SLACK_WEBHOOK_URL_REPLACE_ME"

  # Input for Weather API Key (ensure this is provided securely)
  # Example using an environment variable:
  weather_api_key = get_env("TF_VAR_weather_api_key", "")
  # Or directly (less secure):
  # weather_api_key = "YOUR_WEATHER_API_KEY_REPLACE_ME"

  # --- Optional Inputs for Grafana Secret ---
  # monitoring_namespace    = "monitoring" # Override if needed
  # k8s_grafana_secret_name = "grafana-admin-credentials" # Override if needed

  # --- Optional Inputs for K8s Secret Names & Namespaces ---
  # data_namespace          = "data"
  # monitoring_namespace    = "monitoring"
  # app_namespace           = "app"
  # k8s_root_secret_name    = "mysql-root-credential"
  # k8s_app_secret_name     = "mysql-app-credential" # For MySQL
  # k8s_grafana_secret_name = "grafana-admin-credentials"
  # k8s_slack_secret_name   = "alertmanager-slack-webhook"
  # k8s_weather_secret_name = "weather-api-key"
  # k8s_app_mysql_secret_name = "mysql-app-credentials" # For App
}