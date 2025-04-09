resource "kubernetes_namespace" "data" {
  metadata {
    name = "data"
  }
}

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
}

resource "kubernetes_namespace" "security" {
  metadata {
    name = "security"
  }
}

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
    namespace = kubernetes_namespace.data.metadata[0].name
  })
  depends_on = [kubernetes_namespace.data]
}

resource "kubectl_manifest" "namespace_logging_deny" {
  yaml_body = templatefile("${path.module}/templates/default-deny.yaml", {
    namespace = kubernetes_namespace.logging.metadata[0].name
  })
  depends_on = [kubernetes_namespace.logging]
}

resource "kubectl_manifest" "allow_dns" {
  for_each = toset(["default", "monitoring", "keda", "argocd", "external-secrets", "data", "logging", "karpenter", "security"])
  
  yaml_body = templatefile("${path.module}/templates/allow-dns.yaml", {
    namespace = each.key
  })

  depends_on = [
    kubectl_manifest.namespace_default_deny,
    kubectl_manifest.namespace_monitoring_deny,
    kubectl_manifest.namespace_keda_deny,
    kubectl_manifest.namespace_argocd_deny,
    kubectl_manifest.namespace_external_secrets_deny,
    kubectl_manifest.namespace_data_deny,
    kubectl_manifest.namespace_logging_deny,
    # Add dependencies for karpenter/security if default-deny is applied to them
    kubernetes_namespace.data,
    kubernetes_namespace.logging,
    kubernetes_namespace.security
  ]
}

resource "kubectl_manifest" "app_to_mysql" {
  yaml_body = templatefile("${path.module}/templates/app-to-mysql.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_default_deny,
    kubernetes_namespace.data
  ]
}

resource "kubectl_manifest" "app_to_elasticsearch" {
  yaml_body = templatefile("${path.module}/templates/app-to-elasticsearch.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_default_deny,
    kubernetes_namespace.data
  ]
}

resource "kubectl_manifest" "fluentd_to_elasticsearch" {
  yaml_body = templatefile("${path.module}/templates/fluentd-to-elasticsearch.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_logging_deny,
    kubernetes_namespace.data,
    kubernetes_namespace.logging
  ]
}

resource "kubectl_manifest" "prometheus_to_targets" {
  yaml_body = templatefile("${path.module}/templates/prometheus-to-targets.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_monitoring_deny
  ]
}

resource "kubectl_manifest" "allow_ingress_to_app" {
  yaml_body = templatefile("${path.module}/templates/allow-ingress-to-app.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_default_deny
  ]
}

resource "kubectl_manifest" "keda_to_prometheus" {
  yaml_body = templatefile("${path.module}/templates/keda-to-prometheus.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_keda_deny,
    kubectl_manifest.namespace_monitoring_deny
  ]
}

resource "kubectl_manifest" "external_secrets_to_api" {
  yaml_body = templatefile("${path.module}/templates/external-secrets-egress.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_external_secrets_deny
  ]
}

resource "kubectl_manifest" "allow_app_egress_internet" {
  yaml_body = templatefile("${path.module}/templates/allow-app-egress-internet.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_default_deny
  ]
}

resource "kubectl_manifest" "allow_grafana_egress" {
  yaml_body = templatefile("${path.module}/templates/allow-grafana-egress.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_monitoring_deny,
    kubernetes_namespace.data
  ]
}

resource "kubectl_manifest" "allow_alertmanager_egress" {
  yaml_body = templatefile("${path.module}/templates/allow-alertmanager-egress.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_monitoring_deny
  ]
}

resource "kubectl_manifest" "allow_karpenter_egress" {
  # Note: Assumes karpenter namespace exists
  yaml_body = templatefile("${path.module}/templates/allow-karpenter-egress.yaml", {})

  # Add dependency if karpenter namespace is managed elsewhere or add default-deny for it
}

resource "kubectl_manifest" "allow_elasticsearch_inter_node" {
  yaml_body = templatefile("${path.module}/templates/allow-elasticsearch-inter-node.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_data_deny,
    kubernetes_namespace.data
  ]
}

resource "kubectl_manifest" "allow_argocd_egress" {
  yaml_body = templatefile("${path.module}/templates/allow-argocd-egress.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_argocd_deny
  ]
}