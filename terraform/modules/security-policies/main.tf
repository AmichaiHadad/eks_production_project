resource "helm_release" "polaris" {
  count = var.enabled ? 1 : 0

  name       = "polaris"
  repository = "https://charts.fairwinds.com/stable"
  chart      = "polaris"
  namespace  = "security"
  create_namespace = false
  version    = var.polaris_helm_chart_version

  set {
    name  = "crds.create"
    value = "false"
  }

  values = [
    templatefile("${path.module}/templates/polaris-values.yaml", {})
  ]

  # Add node placement settings
  set {
    name  = "dashboard.nodeSelector.node-role"
    value = "management"
  }
  set {
    name  = "dashboard.tolerations[0].key"
    value = "management"
  }
  set {
    name  = "dashboard.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "dashboard.tolerations[0].value"
    value = "true"
    type  = "string"
  }
  set {
    name  = "dashboard.tolerations[0].effect"
    value = "NoSchedule"
  }
}