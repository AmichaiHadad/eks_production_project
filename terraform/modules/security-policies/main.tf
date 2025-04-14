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

# --- Argo CD Permissions for ExternalSecrets in 'data' namespace ---

resource "kubernetes_role_v1" "argocd_external_secret_manager_data" {
  provider = kubernetes

  metadata {
    name      = "argocd-external-secret-manager"
    namespace = "data" # Grant permissions specifically in the data namespace
    labels = {
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["externalsecrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding_v1" "argocd_external_secret_manager_data" {
  provider = kubernetes

  metadata {
    name      = "argocd-external-secret-manager"
    namespace = "data" # Bind the role in the data namespace
    labels = {
      "app.kubernetes.io/part-of" = "argocd"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.argocd_external_secret_manager_data.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "argocd-application-controller" # Default Argo CD Application Controller SA
    namespace = "argocd" # Namespace where Argo CD runs
  }

  # Ensure this runs after the namespace exists if managed by Terraform
  # depends_on = [kubernetes_namespace_v1.data] # Uncomment if 'data' ns is managed here
}

#------------------------------------------------------------------------------
# RBAC for MySQL Secret Access in 'data' Namespace
#------------------------------------------------------------------------------

resource "kubernetes_role_v1" "data_secret_reader" {
   metadata {
    name      = "secret-reader"
    namespace = "data"
  }
  rule {
    api_groups = [""] # Core API group
    resources  = ["secrets"]
    verbs      = ["get", "watch", "list"]
  }
}

resource "kubernetes_service_account_v1" "mysql_sa" {
  metadata {
    name      = "mysql-sa"
    namespace = "data"
    # Optional: Add annotations for IRSA if needed, though likely not for secret reading within cluster
    # annotations = {
    #   "eks.amazonaws.com/role-arn" = "arn:aws:iam::ACCOUNT_ID:role/YourMySQLSpecificIAMRole"
    # }
  }
  automount_service_account_token = true # Default is usually true, explicit for clarity
}

resource "kubernetes_role_binding_v1" "mysql_sa_secret_reader_binding" {
  depends_on = [
    kubernetes_role_v1.data_secret_reader,
    kubernetes_service_account_v1.mysql_sa
  ]
  metadata {
    name      = "mysql-sa-secret-reader-binding"
    namespace = "data"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.data_secret_reader.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.mysql_sa.metadata[0].name
    namespace = kubernetes_service_account_v1.mysql_sa.metadata[0].namespace
  }
} 