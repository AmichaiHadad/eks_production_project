resource "kubectl_manifest" "restricted_pod_security_standard" {
  yaml_body = templatefile("${path.module}/templates/restricted-pss.yaml", {})
}

resource "helm_release" "polaris" {
  name       = "polaris"
  repository = "https://charts.fairwinds.com/stable"
  chart      = "polaris"
  version    = "5.18.0"
  namespace  = "security"
  create_namespace = true

  values = [
    templatefile("${path.module}/templates/polaris-values.yaml", {})
  ]
}