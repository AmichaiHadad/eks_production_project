resource "kubectl_manifest" "restricted_pod_security_standard" {
  yaml_body = templatefile("${path.module}/templates/restricted-pss.yaml", {})
}

resource "kubectl_manifest" "trivy_operator" {
  yaml_body = templatefile("${path.module}/templates/trivy-operator.yaml", {
    namespace = "security"
  })
}

resource "kubectl_manifest" "vulnerability_scanning_config" {
  yaml_body = templatefile("${path.module}/templates/vulnerability-scan.yaml", {
    namespace = "security"
  })

  depends_on = [
    kubectl_manifest.trivy_operator
  ]
}

resource "kubectl_manifest" "security_audit_policy" {
  yaml_body = templatefile("${path.module}/templates/audit-policy.yaml", {})
}

resource "kubectl_manifest" "ecr_image_scanner_policy" {
  yaml_body = templatefile("${path.module}/templates/ecr-scan-policy.yaml", {})
}

resource "helm_release" "polaris" {
  name       = "polaris"
  repository = "https://charts.fairwinds.com/stable"
  chart      = "polaris"
  namespace  = "security"
  create_namespace = true

  values = [
    templatefile("${path.module}/templates/polaris-values.yaml", {})
  ]
}