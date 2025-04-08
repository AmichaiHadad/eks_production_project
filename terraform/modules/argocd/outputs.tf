output "argocd_namespace" {
  description = "Namespace where Argo CD is deployed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_service" {
  description = "Service name of the Argo CD server"
  value       = "argocd-server"
}

output "argocd_initial_admin_password" {
  description = "Initial admin password for Argo CD"
  value       = data.kubernetes_secret.argocd_initial_admin_password.data.password
  sensitive   = true
}

output "lb_controller_role_arn" {
  description = "ARN of the IAM role used by the AWS Load Balancer Controller"
  value       = aws_iam_role.load_balancer_controller.arn
}