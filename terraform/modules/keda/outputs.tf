output "keda_controller_role_arn" {
  description = "ARN of the IAM role for KEDA controller"
  value       = aws_iam_role.keda_controller.arn
}

output "keda_controller_role_name" {
  description = "Name of the IAM role for KEDA controller"
  value       = aws_iam_role.keda_controller.name
}

output "keda_scaled_object_name" {
  description = "Name of the KEDA ScaledObject"
  value       = jsondecode(kubectl_manifest.keda_scaled_object.yaml_body).metadata.name
}