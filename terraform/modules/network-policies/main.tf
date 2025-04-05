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

resource "kubectl_manifest" "allow_dns" {
  for_each = toset(["default", "monitoring", "keda", "argocd", "external-secrets"])
  
  yaml_body = templatefile("${path.module}/templates/allow-dns.yaml", {
    namespace = each.key
  })

  depends_on = [
    kubectl_manifest.namespace_default_deny,
    kubectl_manifest.namespace_monitoring_deny,
    kubectl_manifest.namespace_keda_deny,
    kubectl_manifest.namespace_argocd_deny,
    kubectl_manifest.namespace_external_secrets_deny
  ]
}

resource "kubectl_manifest" "app_to_mysql" {
  yaml_body = templatefile("${path.module}/templates/app-to-mysql.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_default_deny
  ]
}

resource "kubectl_manifest" "app_to_elasticsearch" {
  yaml_body = templatefile("${path.module}/templates/app-to-elasticsearch.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_default_deny
  ]
}

resource "kubectl_manifest" "fluentd_to_elasticsearch" {
  yaml_body = templatefile("${path.module}/templates/fluentd-to-elasticsearch.yaml", {})

  depends_on = [
    kubectl_manifest.namespace_default_deny
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