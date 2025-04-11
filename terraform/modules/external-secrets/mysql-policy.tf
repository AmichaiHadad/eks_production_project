resource "aws_iam_policy" "mysql_secret_access" {
  name        = "${var.cluster_name}-mysql-secret-access"
  description = "Policy for External Secrets Operator to access MySQL secrets in AWS Secrets Manager"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.secret_prefix}/mysql-app-user-*"
        ]
      },
      # Allow ListSecrets and tag operations for the find functionality
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets",
          "secretsmanager:GetResourcePolicy",
          "tag:GetResources"
        ]
        Resource = ["*"]
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "mysql_secret_access" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.mysql_secret_access.arn
} 