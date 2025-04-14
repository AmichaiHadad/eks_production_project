/**
 * Node Groups Module
 * Creates four managed node groups for:
 * - Monitoring (Prometheus, Grafana)
 * - Management (Argo CD, controllers)
 * - Services (Application workloads)
 * - Data (MySQL, Elasticsearch)
 */

# Common IAM role for EKS node groups
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach common managed policies to node IAM role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_node_role.name
}

# Data node group needs additional EBS permissions
resource "aws_iam_role" "eks_data_node_role" {
  name = "${var.cluster_name}-data-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach policies to data node IAM role
resource "aws_iam_role_policy_attachment" "data_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_data_node_role.name
}

resource "aws_iam_role_policy_attachment" "data_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_data_node_role.name
}

resource "aws_iam_role_policy_attachment" "data_ec2_container_registry_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_data_node_role.name
}

resource "aws_iam_role_policy_attachment" "data_cloudwatch_agent_server_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_data_node_role.name
}

# Add EBS permissions for the data node group
resource "aws_iam_policy" "ebs_access_policy" {
  name        = "${var.cluster_name}-ebs-access-policy"
  description = "Policy for EKS Data nodes to manage EBS volumes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AttachVolume",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteSnapshot",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications",
          "ec2:DetachVolume",
          "ec2:ModifyVolume"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "data_ebs_access_policy" {
  policy_arn = aws_iam_policy.ebs_access_policy.arn
  role       = aws_iam_role.eks_data_node_role.name
}

# Monitoring Node Group
resource "aws_eks_node_group" "monitoring" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-monitoring"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.monitoring_instance_types
  capacity_type  = "ON_DEMAND"
  
  scaling_config {
    desired_size = var.monitoring_desired_size
    min_size     = var.monitoring_min_size
    max_size     = var.monitoring_max_size
  }

  # Add labels and taints for monitoring workloads
  taint {
    key    = "monitoring"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "node-role" = "monitoring"
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-monitoring-node"
    }
  )

  # Ensure IAM role is created first
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read,
    aws_iam_role_policy_attachment.cloudwatch_agent_server_policy
  ]
}

# Management Node Group
resource "aws_eks_node_group" "management" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-management"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.management_instance_types
  capacity_type  = "ON_DEMAND"
  
  scaling_config {
    desired_size = var.management_desired_size
    min_size     = var.management_min_size
    max_size     = var.management_max_size
  }

  # Add labels and taints for management workloads
  taint {
    key    = "management"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "node-role" = "management"
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-management-node"
    }
  )

  # Ensure IAM role is created first
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read,
    aws_iam_role_policy_attachment.cloudwatch_agent_server_policy
  ]
}

# Services Node Group
resource "aws_eks_node_group" "services" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-services"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.services_instance_types
  capacity_type  = "ON_DEMAND"
  
  scaling_config {
    desired_size = var.services_desired_size
    min_size     = var.services_min_size
    max_size     = var.services_max_size
  }

  # Services nodes are default (no taint)
  labels = {
    "node-role" = "services"
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-services-node"
    }
  )

  # Ensure IAM role is created first
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read,
    aws_iam_role_policy_attachment.cloudwatch_agent_server_policy
  ]
}

# Data Node Group
resource "aws_eks_node_group" "data" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-data"
  node_role_arn   = aws_iam_role.eks_data_node_role.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.data_instance_types
  capacity_type  = "ON_DEMAND"
  
  scaling_config {
    desired_size = var.data_desired_size
    min_size     = var.data_min_size
    max_size     = var.data_max_size
  }

  # Add labels and taints for data workloads
  taint {
    key    = "role"
    value  = "data"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "node-role" = "data"
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.cluster_name}-data-node"
    }
  )

  # Ensure IAM role is created first
  depends_on = [
    aws_iam_role_policy_attachment.data_eks_worker_node_policy,
    aws_iam_role_policy_attachment.data_eks_cni_policy,
    aws_iam_role_policy_attachment.data_ec2_container_registry_read,
    aws_iam_role_policy_attachment.data_cloudwatch_agent_server_policy,
    aws_iam_role_policy_attachment.data_ebs_access_policy
  ]
}