output "monitoring_node_group_id" {
  description = "ID of the monitoring node group"
  value       = aws_eks_node_group.monitoring.id
}

output "monitoring_node_group_arn" {
  description = "ARN of the monitoring node group"
  value       = aws_eks_node_group.monitoring.arn
}

output "management_node_group_id" {
  description = "ID of the management node group"
  value       = aws_eks_node_group.management.id
}

output "management_node_group_arn" {
  description = "ARN of the management node group"
  value       = aws_eks_node_group.management.arn
}

output "services_node_group_id" {
  description = "ID of the services node group"
  value       = aws_eks_node_group.services.id
}

output "services_node_group_arn" {
  description = "ARN of the services node group"
  value       = aws_eks_node_group.services.arn
}

output "data_node_group_id" {
  description = "ID of the data node group"
  value       = aws_eks_node_group.data.id
}

output "data_node_group_arn" {
  description = "ARN of the data node group"
  value       = aws_eks_node_group.data.arn
}

output "node_role_arn" {
  description = "ARN of the common node IAM role"
  value       = aws_iam_role.eks_node_role.arn
}

output "data_node_role_arn" {
  description = "ARN of the data node IAM role"
  value       = aws_iam_role.eks_data_node_role.arn
}

output "node_role_name" {
  description = "Name of the common node IAM role"
  value       = aws_iam_role.eks_node_role.name
}