variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs to use for the EKS node groups (private subnets)"
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# Monitoring Node Group variables
variable "monitoring_instance_types" {
  description = "List of instance types for the monitoring node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "monitoring_desired_size" {
  description = "Desired number of nodes in the monitoring node group"
  type        = number
  default     = 2
}

variable "monitoring_min_size" {
  description = "Minimum number of nodes in the monitoring node group"
  type        = number
  default     = 1
}

variable "monitoring_max_size" {
  description = "Maximum number of nodes in the monitoring node group"
  type        = number
  default     = 3
}

# Management Node Group variables
variable "management_instance_types" {
  description = "List of instance types for the management node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "management_desired_size" {
  description = "Desired number of nodes in the management node group"
  type        = number
  default     = 2
}

variable "management_min_size" {
  description = "Minimum number of nodes in the management node group"
  type        = number
  default     = 1
}

variable "management_max_size" {
  description = "Maximum number of nodes in the management node group"
  type        = number
  default     = 3
}

# Services Node Group variables
variable "services_instance_types" {
  description = "List of instance types for the services node group"
  type        = list(string)
  default     = ["m5.large"]
}

variable "services_desired_size" {
  description = "Desired number of nodes in the services node group"
  type        = number
  default     = 2
}

variable "services_min_size" {
  description = "Minimum number of nodes in the services node group"
  type        = number
  default     = 2
}

variable "services_max_size" {
  description = "Maximum number of nodes in the services node group"
  type        = number
  default     = 5
}

# Data Node Group variables
variable "data_instance_types" {
  description = "List of instance types for the data node group"
  type        = list(string)
  default     = ["r5.xlarge"]
}

variable "data_desired_size" {
  description = "Desired number of nodes in the data node group"
  type        = number
  default     = 3
}

variable "data_min_size" {
  description = "Minimum number of nodes in the data node group"
  type        = number
  default     = 3
}

variable "data_max_size" {
  description = "Maximum number of nodes in the data node group"
  type        = number
  default     = 5
}