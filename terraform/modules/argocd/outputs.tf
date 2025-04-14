output "deploy_complete" {
  description = "Dummy output to enforce deployment order."
  value       = true
} 

output "argocd_namespace" {
  description = "Namespace where Argo CD is deployed"
  value       = var.namespace
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

output "argocd_ingress_hostname" {
  description = "Hostname where ArgoCD is accessible"
  value       = var.ingress_host
}

output "argocd_ingress_created" {
  description = "The ID of the ArgoCD ingress created"
  value       = kubernetes_ingress_v1.argocd_ingress.id
}