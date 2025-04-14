# Argo CD configuration for us-east-1 region

# Include the root terragrunt.hcl configuration
include {
  path = find_in_parent_folders()
}

# Include the region configuration
include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

# Terraform source
terraform {
  source = "../../../terraform/modules/argocd"
}

# Dependencies: Must run after external secrets
dependencies {
  paths = ["../networking", "../eks", "../node-groups", "../external-secrets"]
}

dependency "vpc" {
  config_path = "../networking"
}

dependency "eks" {
  config_path = "../eks"
}

dependency "node_groups" {
  config_path = "../node-groups"
}

dependency "external_secrets" {
  config_path = "../external-secrets"

  # Mock outputs are necessary for plan to succeed before external-secrets is applied
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    slack_webhook_secret_name = "mock-slack-webhook"
    grafana_admin_secret_name = "mock-grafana-admin"
    weather_api_secret_name   = "mock-weather-api"
    mysql_app_user_secret_name = "mock-mysql-app-user"
  }
}

locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  region      = local.region_vars.locals.aws_region
}

# Top-level inputs merged from module needs and included provider needs
inputs = merge(
  # Inputs required by the included kubernetes_providers.hcl
  {
    cluster_name                       = dependency.eks.outputs.cluster_name
    cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
    cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
    aws_region                         = include.region.locals.aws_region
    vpc_id                             = dependency.vpc.outputs.vpc_id
  },
  # Original inputs for this module
  {
    cluster_name            = dependency.eks.outputs.cluster_name
    cluster_oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
    namespace               = "argocd"
    argocd_helm_chart_version = "7.8.23"  # Compatible with Argo CD 2.14+
    ingress_enabled         = true
    ingress_host            = "argocd-${include.region.locals.aws_region}.${include.region.locals.domain_name}"
    ingress_tls_secret      = include.region.locals.acm_certificate_arn
    service_type            = "ClusterIP"
    node_selector           = {
      "node-role" = "management"
    }
    toleration_key          = "management"
    toleration_value        = "true"
    toleration_effect       = "NoSchedule"
    application_sets = [
      {
        name            = "monitoring"
        repo_url        = "https://github.com/AmichaiHadad/eks_app_2.git"
        path            = "argocd" # Points to monitoring-applicationset.yaml
        target_revision = "HEAD"
        target_namespace = "argocd"
        auto_sync       = true
        self_heal       = true
        values = {
          slack_webhook_secret_name = dependency.external_secrets.outputs.slack_webhook_secret_name
          grafana_admin_secret_name = dependency.external_secrets.outputs.grafana_admin_secret_name
          cluster = "eks-blizzard-us-east-1" # Example value
          url     = "https://kubernetes.default.svc" # Example value
          region  = "us-east-1" # Example value
        }
      },
      {
        name            = "app"
        repo_url        = "https://github.com/AmichaiHadad/eks_app_2.git"
        path            = "argocd" # Points to app-applicationset.yaml
        target_revision = "HEAD"
        target_namespace = "argocd"
        auto_sync       = true
        self_heal       = true
        values = {
          weather_api_aws_secret_name = dependency.external_secrets.outputs.weather_api_secret_name
          mysql_app_user_aws_secret_name = dependency.external_secrets.outputs.mysql_app_user_secret_name
          cluster = "eks-blizzard-us-east-1" # Example value
          url     = "https://kubernetes.default.svc" # Example value
          region  = "us-east-1" # Example value
          acm_certificate_arn = include.region.locals.acm_certificate_arn # Needed by app appset
        }
      },
      {
        name            = "mysql"
        repo_url        = "https://github.com/AmichaiHadad/eks_app_2.git"
        path            = "argocd" # Points to mysql-applicationset.yaml (after rename)
        target_revision = "HEAD"
        target_namespace = "argocd"
        auto_sync       = true
        self_heal       = true
        values = {
           mysql_app_user_aws_secret_name = dependency.external_secrets.outputs.mysql_app_user_secret_name
           cluster = "eks-blizzard-us-east-1" # Example value
           url     = "https://kubernetes.default.svc" # Example value
           namespace = "data"
           region  = "us-east-1" # Example value
        }
      },
      {
        name            = "elasticsearch"
        repo_url        = "https://github.com/AmichaiHadad/eks_app_2.git"
        path            = "argocd" # Points to elasticsearch-applicationset.yaml (new file)
        target_revision = "HEAD"
        target_namespace = "argocd"
        auto_sync       = true
        self_heal       = true
        values = {
           cluster = "eks-blizzard-us-east-1" # Example value
           url     = "https://kubernetes.default.svc" # Example value
           namespace = "data"
           region  = "us-east-1" # Example value
        }
      },
      {
        name            = "fluentd"
        repo_url        = "https://github.com/AmichaiHadad/eks_app_2.git"
        path            = "argocd" # Points to fluentd-applicationset.yaml (new file)
        target_revision = "HEAD"
        target_namespace = "argocd"
        auto_sync       = true
        self_heal       = true
        values = {
           cluster = "eks-blizzard-us-east-1" # Example value
           url     = "https://kubernetes.default.svc" # Example value
           namespace = "logging"
           region  = "us-east-1" # Example value
        }
      }
    ]
    tags = {
      Region      = include.region.locals.aws_region
      Environment = "production"
    }
  }
)