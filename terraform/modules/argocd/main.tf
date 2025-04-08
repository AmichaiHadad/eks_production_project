/**
 * Argo CD Module
 * Installs Argo CD in the EKS cluster to enable GitOps continuous delivery
 */

# Create the argocd namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

# Argo CD Helm release - Install AFTER AWS Load Balancer Controller
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_helm_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  # Removed aggressive recreation options for stable deployments
  # force_update = true
  # replace    = true
  # recreate_pods = true

  # Override default values with custom values
  values = [
    templatefile("${path.module}/templates/values.yaml", {
      # Pass variables to values.yaml template
      ingress_enabled       = var.ingress_enabled
      ingress_host          = var.ingress_host
      ingress_tls_secret    = var.ingress_tls_secret
      service_type          = var.service_type
      node_selector         = jsonencode(var.node_selector)
      toleration_key        = var.toleration_key
      toleration_value      = var.toleration_value
      toleration_effect     = var.toleration_effect
    })
  ]

  # Dependencies - Must deploy LB Controller first to have the webhook ready for ingress validation
  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.aws_load_balancer_controller
  ]

  # Wait for Argo CD to be deployed and ready
  timeout    = 900
  wait       = true
  wait_for_jobs = true
  
  # Increase retry attempts
  set {
    name  = "server.initialDelaySeconds"
    value = "30"
  }
  
  # Removed aggressive lifecycle policy once deployment is stable
  # lifecycle {
  #   create_before_destroy = true
  # }
}

# Extract the initial admin password
data "kubernetes_secret" "argocd_initial_admin_password" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  depends_on = [
    helm_release.argocd
  ]
}

# Create ApplicationSet resource for deploying applications
resource "kubectl_manifest" "applicationset" {
  count = length(var.application_sets)
  yaml_body = templatefile("${path.module}/templates/applicationset.yaml", {
    name        = var.application_sets[count.index].name
    namespace   = kubernetes_namespace.argocd.metadata[0].name
    repo_url    = var.application_sets[count.index].repo_url
    path        = var.application_sets[count.index].path
    target_revision = var.application_sets[count.index].target_revision
    target_namespace = var.application_sets[count.index].target_namespace
    auto_sync    = var.application_sets[count.index].auto_sync
    self_heal    = var.application_sets[count.index].self_heal
  })
  depends_on = [
    helm_release.argocd
  ]
}

# Look up the Route53 zone ID for the domain if dns_managed is true
data "aws_route53_zone" "domain" {
  count = var.dns_managed && var.ingress_enabled ? 1 : 0
  name  = var.domain_name
  private_zone = false
}

# Wait for the ingress to have a load balancer address
resource "null_resource" "wait_for_alb" {
  count = var.dns_managed && var.ingress_enabled ? 1 : 0
  
  triggers = {
    ingress_name = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "Waiting for ALB address to be available..."
      for i in {1..30}; do
        ALB_ADDRESS=$(kubectl get ingress -n ${kubernetes_namespace.argocd.metadata[0].name} argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        if [ -n "$ALB_ADDRESS" ]; then
          echo "ALB address found: $ALB_ADDRESS"
          exit 0
        fi
        echo "Attempt $i: ALB address not yet available, waiting..."
        sleep 10
      done
      echo "Timed out waiting for ALB address"
      exit 1
    EOT
  }
  
  depends_on = [
    helm_release.argocd
  ]
}

# Get the ALB address from the ingress
data "kubernetes_ingress_v1" "argocd_ingress" {
  count = var.dns_managed && var.ingress_enabled ? 1 : 0
  
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  
  depends_on = [
    helm_release.argocd,
    null_resource.wait_for_alb
  ]
}

# Check if DNS record already exists before creating/updating
resource "null_resource" "check_dns_record" {
  count = var.dns_managed && var.ingress_enabled ? 1 : 0
  
  triggers = {
    host = var.ingress_host
    alb_hostname = data.kubernetes_ingress_v1.argocd_ingress[0].status[0].load_balancer[0].ingress[0].hostname
  }
  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      # Get the current ALB address from the ingress
      ALB_HOSTNAME="${data.kubernetes_ingress_v1.argocd_ingress[0].status[0].load_balancer[0].ingress[0].hostname}"
      RECORD_NAME="${var.ingress_host}."
      ZONE_ID="${data.aws_route53_zone.domain[0].zone_id}"
      
      echo "Checking if DNS record $RECORD_NAME already exists..."
      
      # Create the change batch file for upsert operation
      cat > /tmp/route53-upsert.json << EOF
      {
        "Changes": [
          {
            "Action": "UPSERT",
            "ResourceRecordSet": {
              "Name": "$RECORD_NAME",
              "Type": "CNAME",
              "TTL": 60,
              "ResourceRecords": [
                {
                  "Value": "$ALB_HOSTNAME"
                }
              ]
            }
          }
        ]
      }
      EOF
      
      # Apply the change using UPSERT to create or update as needed
      aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file:///tmp/route53-upsert.json
      
      echo "DNS record has been created or updated to point to: $ALB_HOSTNAME"
    EOT
  }
  
  depends_on = [
    helm_release.argocd,
    null_resource.wait_for_alb,
    data.kubernetes_ingress_v1.argocd_ingress
  ]
}

# This placeholder resource allows Terraform to track the DNS change
# We're using null_resource for the actual update to handle both create and update cases
resource "aws_route53_record" "argocd" {
  count   = 0 # Disabled in favor of the null_resource approach
  zone_id = data.aws_route53_zone.domain[0].zone_id
  name    = var.ingress_host
  type    = "CNAME"
  ttl     = 60
  records = ["placeholder"]
}

# This data source has been moved up to coordinate with the DNS record creation

# Create AWS Load Balancer Controller IAM role for service account (IRSA)
resource "aws_iam_role" "load_balancer_controller" {
  name = "${var.cluster_name}-lb-controller-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.cluster_oidc_provider_arn, "/^arn:aws:iam::[0-9]*:oidc-provider\\//", "")}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.cluster_name}-lb-controller-policy"
  description = "Policy for AWS Load Balancer Controller"
  
  policy = file("${path.module}/policies/aws-load-balancer-controller-policy.json")
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

# Install AWS Load Balancer Controller FIRST
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lb_controller_helm_chart_version
  namespace  = "kube-system"
  # Removed aggressive recreation options for stable deployments
  # force_update = true
  # replace    = true
  # recreate_pods = true

  # All configuration is now in the values block for better YAML handling
  values = [
    <<-EOT
    # Core settings
    clusterName: ${var.cluster_name}
    serviceAccount:
      create: true
      name: aws-load-balancer-controller
      annotations:
        eks.amazonaws.com/role-arn: ${aws_iam_role.load_balancer_controller.arn}
    
    # Node assignment
    nodeSelector:
      node-role: management
    
    # Tolerations with proper string quoting
    tolerations:
    - key: "${var.toleration_key}"
      value: "${var.toleration_value}"
      effect: "${var.toleration_effect}"
      operator: "Equal"
    
    # Configuration options
    enableCertManager: false
    enableServiceMutatorWebhook: true
    EOT
  ]

  # No explicit dependency on ArgoCD namespace - this avoids circular dependency
  # The LB Controller should be independent of ArgoCD
  depends_on = [
    aws_iam_role_policy_attachment.load_balancer_controller
  ]
  
  # Add timeout to ensure proper deployment
  timeout = 900
  
  # Removed aggressive lifecycle policy once deployment is stable
  # lifecycle {
  #   create_before_destroy = true
  # }
}