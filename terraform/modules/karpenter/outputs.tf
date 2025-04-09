output "karpenter_controller_role_arn" {
  description = "ARN of the IAM role for Karpenter controller"
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_controller_role_name" {
  description = "Name of the IAM role for Karpenter controller"
  value       = aws_iam_role.karpenter_controller.name
}

output "karpenter_nodepool_name" {
  description = "Name of the Karpenter provisioner"
  value       = "default"
}