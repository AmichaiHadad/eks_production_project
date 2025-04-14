# Remove namespace resource blocks for data, logging, security, trivy_system
# Assume these namespaces are created by their respective Helm charts or other means.

# Apply default deny policies to existing namespaces
resource "kubectl_manifest" "namespace_default_deny" {
  yaml_body = templatefile("${path.module}/templates/default-deny.yaml", {
    namespace = "default"
  })
}

resource "kubectl_manifest" "namespace_monitoring_deny" {
  yaml_body = templatefile("${path.module}/templates/default-deny.yaml", {
    namespace = "monitoring"
  })
}

resource "kubectl_manifest" "namespace_keda_deny" {
  yaml_body = templatefile("${path.module}/templates/default-deny.yaml", {
    namespace = "keda"
  })
}

resource "kubectl_manifest" "namespace_argocd_deny" {
  yaml_body = templatefile("${path.module}/templates/default-deny.yaml", {
    namespace = "argocd"
  })
}

resource "kubectl_manifest" "namespace_external_secrets_deny" {
  yaml_body = templatefile("${path.module}/templates/default-deny.yaml", {
    namespace = "external-secrets"
  })
}

resource "kubectl_manifest" "namespace_data_deny" {
  yaml_body = templatefile("${path.module}/templates/default-deny.yaml", {
    namespace = "data"
  })
  # No depends_on needed as we assume namespace exists
}

resource "kubectl_manifest" "namespace_logging_deny" {
  yaml_body = templatefile("${path.module}/templates/default-deny.yaml", {
    namespace = "logging"
  })
  # No depends_on needed
}

resource "kubectl_manifest" "namespace_trivy_system_deny" {
  yaml_body = templatefile("${path.module}/templates/default-deny.yaml", {
    namespace = "trivy-system" # Use static name
  })
  # No depends_on needed
}

resource "kubectl_manifest" "namespace_security_deny" {
  yaml_body = templatefile("${path.module}/templates/default-deny.yaml", {
    namespace = "security"
  })
  # No depends_on needed
}

# Apply DNS allow policies
resource "kubectl_manifest" "allow_dns" {
  # Include trivy-system in the list
  for_each = toset(["default", "monitoring", "keda", "argocd", "external-secrets", "data", "logging", "karpenter", "security", "trivy-system"])

  yaml_body = templatefile("${path.module}/templates/allow-dns.yaml", {
    namespace = each.key
  })

  # Depend on the default deny policies being applied first
  depends_on = [
    kubectl_manifest.namespace_default_deny,
    kubectl_manifest.namespace_monitoring_deny,
    kubectl_manifest.namespace_keda_deny,
    kubectl_manifest.namespace_argocd_deny,
    kubectl_manifest.namespace_external_secrets_deny,
    kubectl_manifest.namespace_data_deny,
    kubectl_manifest.namespace_logging_deny,
    kubectl_manifest.namespace_security_deny,
    kubectl_manifest.namespace_trivy_system_deny
    # Add dependency for karpenter default deny if managed here
  ]
}

# Apply specific cross-namespace policies
resource "kubectl_manifest" "app_to_mysql" {
  yaml_body = templatefile("${path.module}/templates/app-to-mysql.yaml", {})
  # Depend on default denies
  depends_on = [kubectl_manifest.namespace_default_deny, kubectl_manifest.namespace_data_deny]
}

resource "kubectl_manifest" "app_to_elasticsearch" {
  yaml_body = templatefile("${path.module}/templates/app-to-elasticsearch.yaml", {})
  # Depend on default denies
  depends_on = [kubectl_manifest.namespace_default_deny, kubectl_manifest.namespace_data_deny]
}

resource "kubectl_manifest" "fluentd_to_elasticsearch" {
  yaml_body = templatefile("${path.module}/templates/fluentd-to-elasticsearch.yaml", {})
  # Depend on default denies
  depends_on = [kubectl_manifest.namespace_logging_deny, kubectl_manifest.namespace_data_deny]
}

resource "kubectl_manifest" "prometheus_to_targets" {
  yaml_body = templatefile("${path.module}/templates/prometheus-to-targets.yaml", {})
  depends_on = [kubectl_manifest.namespace_monitoring_deny]
}

resource "kubectl_manifest" "allow_prometheus_to_trivy" {
  yaml_body = templatefile("${path.module}/templates/allow-prometheus-to-trivy.yaml", {
    trivy_namespace = "trivy-system" # Use static name
  })
  # Depend on default denies
  depends_on = [kubectl_manifest.namespace_trivy_system_deny, kubectl_manifest.namespace_monitoring_deny]
}

resource "kubectl_manifest" "allow_ingress_to_app" {
  yaml_body = templatefile("${path.module}/templates/allow-ingress-to-app.yaml", {})
  depends_on = [kubectl_manifest.namespace_default_deny]
}

resource "kubectl_manifest" "keda_to_prometheus" {
  yaml_body = templatefile("${path.module}/templates/keda-to-prometheus.yaml", {})
  depends_on = [kubectl_manifest.namespace_keda_deny, kubectl_manifest.namespace_monitoring_deny]
}

# Apply egress policies
resource "kubectl_manifest" "external_secrets_to_api" {
  yaml_body = templatefile("${path.module}/templates/external-secrets-egress.yaml", {})
  depends_on = [kubectl_manifest.namespace_external_secrets_deny]
}

resource "kubectl_manifest" "allow_app_egress_internet" {
  yaml_body = templatefile("${path.module}/templates/allow-app-egress-internet.yaml", {})
  depends_on = [kubectl_manifest.namespace_default_deny]
}

resource "kubectl_manifest" "allow_grafana_egress" {
  yaml_body = templatefile("${path.module}/templates/allow-grafana-egress.yaml", {})
  depends_on = [kubectl_manifest.namespace_monitoring_deny, kubectl_manifest.namespace_data_deny]
}

resource "kubectl_manifest" "allow_alertmanager_egress" {
  yaml_body = templatefile("${path.module}/templates/allow-alertmanager-egress.yaml", {})
  depends_on = [kubectl_manifest.namespace_monitoring_deny]
}

resource "kubectl_manifest" "allow_karpenter_egress" {
  yaml_body = templatefile("${path.module}/templates/allow-karpenter-egress.yaml", {})
  # Add dependency for karpenter default deny if managed here
}

resource "kubectl_manifest" "allow_elasticsearch_inter_node" {
  yaml_body = templatefile("${path.module}/templates/allow-elasticsearch-inter-node.yaml", {})
  depends_on = [kubectl_manifest.namespace_data_deny]
}

resource "kubectl_manifest" "allow_argocd_egress" {
  yaml_body = templatefile("${path.module}/templates/allow-argocd-egress.yaml", {})
  depends_on = [kubectl_manifest.namespace_argocd_deny]
}

resource "kubectl_manifest" "trivy_system_allow_api_egress" {
  yaml_body = templatefile("${path.module}/templates/allow-api-egress.yaml", {
    namespace = "trivy-system" # Use static name
  })
  depends_on = [kubectl_manifest.namespace_trivy_system_deny]
}

resource "kubectl_manifest" "trivy_system_allow_internet_egress" {
  yaml_body = templatefile("${path.module}/templates/allow-internet-egress.yaml", {
    namespace = "trivy-system" # Use static name
  })
  depends_on = [kubectl_manifest.namespace_trivy_system_deny]
}