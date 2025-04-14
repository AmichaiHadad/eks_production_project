----------------
-"Module name": networking-
----------------

Deployed components: 
--------------------
- `terraform-aws-modules/vpc/aws` module: Creates the core VPC infrastructure including the VPC itself, public and private subnets across the specified AZs (`us-east-1a`, `us-east-1b`, `us-east-1c`), an Internet Gateway for public subnet outbound access, NAT Gateways (one per AZ) for private subnet outbound access, and associated Route Tables.
- `aws_security_group.eks_cluster_sg`: A security group associated with the VPC, specifically for allowing internal communication within the EKS cluster. It allows all egress traffic and ingress traffic from itself.

Hard coded vars:  
-----------------
- `"kubernetes.io/role/internal-elb": "1"` - `terraform/modules/vpc/main.tf` (Tag for private subnets, used by K8s internal load balancers)
- `"karpenter.sh/discovery": var.eks_cluster_name` - `terraform/modules/vpc/main.tf` (Tag for private subnets, used by Karpenter for subnet discovery)
- `"kubernetes.io/role/elb": "1"` - `terraform/modules/vpc/main.tf` (Tag for public subnets, used by K8s public load balancers)
- `egress from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"]` - `terraform/modules/vpc/main.tf` (Rule in `eks_cluster_sg` allowing all outbound traffic)
- `ingress from_port = 0, to_port = 0, protocol = "-1", self = true` - `terraform/modules/vpc/main.tf` (Rule in `eks_cluster_sg` allowing traffic from resources within the same security group)
- `vpc name pattern: "vpc-${include.region.locals.cluster_name}"` - `terragrunt/us-east-1/networking/terragrunt.hcl`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `aws_region`: `terragrunt/us-east-1/region.hcl` (Value: `us-east-1`)
- `vpc_name`: `terragrunt/us-east-1/networking/terragrunt.hcl` (Value: `vpc-${include.region.locals.cluster_name}`)
- `vpc_cidr`: `terragrunt/us-east-1/region.hcl` (Value: `10.10.0.0/16`)
- `azs`: `terragrunt/us-east-1/region.hcl` (Value: `["us-east-1a", "us-east-1b", "us-east-1c"]`)
- `private_subnet_cidrs`: `terragrunt/us-east-1/region.hcl` (Value: `["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]`)
- `public_subnet_cidrs`: `terragrunt/us-east-1/region.hcl` (Value: `["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]`)
- `private_subnet_tags`: `terragrunt/us-east-1/networking/terragrunt.hcl` (Value: `{"kubernetes.io/cluster/${include.region.locals.cluster_name}" = "shared"}`)
- `public_subnet_tags`: `terragrunt/us-east-1/networking/terragrunt.hcl` (Value: `{"kubernetes.io/cluster/${include.region.locals.cluster_name}" = "shared"}`)
- `tags`: `terragrunt/us-east-1/networking/terragrunt.hcl` (Value: Combines region tags with `Name = "vpc-${include.region.locals.cluster_name}"`)
- `eks_cluster_name`: `terragrunt/us-east-1/region.hcl` (Value: `eks-blizzard-us-east-1`)

Outputs:
--------
- `vpc_id`: The ID of the created VPC.
- `vpc_cidr_block`: The CIDR block of the created VPC.
- `private_subnets`: List of IDs of the created private subnets.
- `private_subnet_arns`: List of ARNs of the created private subnets.
- `private_subnets_cidr_blocks`: List of CIDR blocks of the created private subnets.
- `public_subnets`: List of IDs of the created public subnets.
- `public_subnet_arns`: List of ARNs of the created public subnets.
- `public_subnets_cidr_blocks`: List of CIDR blocks of the created public subnets.
- `nat_public_ips`: List of public Elastic IPs created for the NAT Gateways.
- `cluster_security_group_id`: The ID of the created EKS cluster security group (`eks_cluster_sg`).

Versioning: 
-----------
- Terraform Module: `terraform-aws-modules/vpc/aws` version `~> 5.0`

Providers/Required providers:
------------------------------
- `hashicorp/aws`: `~> 5.0, >= 5.79.0` (Locked version: `5.94.1`)

----------------
-"Module name": eks-
----------------

Deployed components: 
--------------------
- `aws_iam_role.eks_cluster_role`: IAM role assumed by the EKS control plane.
- `aws_iam_role_policy_attachment`: Attaches AWS managed policies (`AmazonEKSClusterPolicy`, `AmazonEKSServicePolicy`) to the cluster role.
- `aws_eks_cluster`: The EKS cluster control plane itself. Configured with specified Kubernetes version, VPC settings (private subnets, security group), private and public endpoint access, and CloudWatch logging enabled.
- `aws_kms_key`: A KMS key used for encrypting Kubernetes secrets within the EKS cluster.
- `aws_kms_alias`: An alias for the KMS key for easier reference.
- `aws_iam_openid_connect_provider`: An IAM OIDC identity provider associated with the cluster's OIDC issuer URL, enabling IRSA (IAM Roles for Service Accounts).

Hard coded vars:  
-----------------
- `enabled_cluster_log_types`: `["api", "audit", "authenticator", "controllerManager", "scheduler"]` - `terraform/modules/eks-cluster/main.tf` (Specifies logs sent to CloudWatch)
- `kms key deletion_window_in_days`: `7` - `terraform/modules/eks-cluster/main.tf`
- `kms key enable_key_rotation`: `true` - `terraform/modules/eks-cluster/main.tf`
- `oidc client_id_list`: `["sts.amazonaws.com"]` - `terraform/modules/eks-cluster/main.tf` (Client ID for the OIDC provider)
- `role name pattern: "${var.cluster_name}-cluster-role"` - `terraform/modules/eks-cluster/main.tf`
- `kms alias pattern: "alias/${var.cluster_name}-encryption-key"` - `terraform/modules/eks-cluster/main.tf`
- `oidc provider tag name pattern: "${var.cluster_name}-eks-oidc-provider"` - `terraform/modules/eks-cluster/main.tf`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `aws_region`: `terragrunt/us-east-1/region.hcl` (Value: `us-east-1`)
- `cluster_name`: `terragrunt/us-east-1/region.hcl` (Value: `eks-blizzard-us-east-1`)
- `kubernetes_version`: `terragrunt/us-east-1/region.hcl` (Value: `1.32`)
- `subnet_ids`: `dependency.vpc.outputs.private_subnets` (From `networking` module)
- `cluster_security_group_id`: `dependency.vpc.outputs.cluster_security_group_id` (From `networking` module)
- `tags`: `terragrunt/us-east-1/eks/terragrunt.hcl` (Combines region tags with `Name = include.region.locals.cluster_name`)

Outputs:
--------
- `cluster_id`: The ID of the EKS cluster.
- `cluster_name`: The name of the EKS cluster.
- `cluster_endpoint`: The endpoint URL for the EKS control plane.
- `cluster_certificate_authority_data`: Base64 encoded CA certificate for the cluster.
- `oidc_provider_arn`: ARN of the IAM OIDC provider for IRSA.
- `oidc_provider_url`: URL of the IAM OIDC provider (without `https://`).
- `cluster_security_group_id`: Security group ID attached to the EKS cluster control plane.
- `cluster_iam_role_arn`: ARN of the EKS cluster IAM role.
- `cluster_iam_role_name`: Name of the EKS cluster IAM role.
- `cluster_arn`: ARN of the EKS cluster.
- `encryption_key_arn`: ARN of the KMS key used for secret encryption.
- `account_id`: The AWS Account ID where the cluster is deployed.
- `vpc_cni_addon_id`: `null` (Managed by `eks-addons` module)
- `coredns_addon_id`: `null` (Managed by `eks-addons` module)
- `kube_proxy_addon_id`: `null` (Managed by `eks-addons` module)

Versioning: 
-----------
- Kubernetes Version: `1.32` (from `region.hcl`)

Providers/Required providers:
------------------------------
- `hashicorp/aws`: `~> 5.0` (Locked version: `5.94.1`)
- `hashicorp/tls`: `4.0.6` (Locked version: `4.0.6`)

----------------
-"Module name": node-groups-
----------------

Deployed components: 
--------------------
- `aws_iam_role.eks_node_role`: A common IAM role assumed by EC2 instances in the monitoring, management, and services node groups.
- `aws_iam_role.eks_data_node_role`: A specific IAM role assumed by EC2 instances in the data node group, including extra EBS permissions.
- `aws_iam_role_policy_attachment`: Attaches necessary AWS managed policies (`AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`, `CloudWatchAgentServerPolicy`) to both node roles.
- `aws_iam_policy.ebs_access_policy`: A custom IAM policy granting permissions needed by the data nodes to interact with EBS volumes (e.g., attach, create snapshot, delete).
- `aws_iam_role_policy_attachment.data_ebs_access_policy`: Attaches the custom EBS policy specifically to the data node role.
- `aws_eks_node_group` (monitoring): Managed node group for monitoring tools (Prometheus, Grafana). Tainted (`monitoring=true:NO_SCHEDULE`) and labeled (`node-role=monitoring`).
- `aws_eks_node_group` (management): Managed node group for management tools (Argo CD, controllers). Tainted (`management=true:NO_SCHEDULE`) and labeled (`node-role=management`).
- `aws_eks_node_group` (services): Managed node group for general application workloads. No taint, labeled (`node-role=services`).
- `aws_eks_node_group` (data): Managed node group for data services (MySQL, Elasticsearch). Tainted (`role=data:NO_SCHEDULE`) and labeled (`node-role=data`). Uses the `eks_data_node_role`.

Hard coded vars:  
-----------------
- Managed Policy ARNs: `arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy`, `arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy`, `arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly`, `arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy` - `terraform/modules/node-groups/main.tf`
- `ebs_access_policy` Actions: `["ec2:AttachVolume", "ec2:CreateSnapshot", ...]` - `terraform/modules/node-groups/main.tf`
- Monitoring Taint: `key="monitoring", value="true", effect="NO_SCHEDULE"` - `terraform/modules/node-groups/main.tf`
- Monitoring Label: `"node-role": "monitoring"` - `terraform/modules/node-groups/main.tf`
- Management Taint: `key="management", value="true", effect="NO_SCHEDULE"` - `terraform/modules/node-groups/main.tf`
- Management Label: `"node-role": "management"` - `terraform/modules/node-groups/main.tf`
- Services Label: `"node-role": "services"` - `terraform/modules/node-groups/main.tf`
- Data Taint: `key="role", value="data", effect="NO_SCHEDULE"` - `terraform/modules/node-groups/main.tf`
- Data Label: `"node-role": "data"` - `terraform/modules/node-groups/main.tf`
- Node Group Capacity Type: `"ON_DEMAND"` - `terraform/modules/node-groups/main.tf`
- Role Name Patterns: `"${var.cluster_name}-node-role"`, `"${var.cluster_name}-data-node-role"` - `terraform/modules/node-groups/main.tf`
- Policy Name Pattern: `"${var.cluster_name}-ebs-access-policy"` - `terraform/modules/node-groups/main.tf`
- Node Group Name Patterns: `"${var.cluster_name}-monitoring"`, `"${var.cluster_name}-management"`, etc. - `terraform/modules/node-groups/main.tf`
- Node Tag Name Patterns: `"${var.cluster_name}-monitoring-node"`, etc. - `terraform/modules/node-groups/main.tf`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `aws_region`: `terragrunt/us-east-1/region.hcl` (Value: `us-east-1`)
- `cluster_name`: `dependency.eks.outputs.cluster_name` (From `eks` module)
- `subnet_ids`: `dependency.vpc.outputs.private_subnets` (From `networking` module)
- `monitoring_instance_types`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `["t3.large"]`)
- `monitoring_desired_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `2`)
- `monitoring_min_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `1`)
- `monitoring_max_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `3`)
- `management_instance_types`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `["t3.medium"]`)
- `management_desired_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `2`)
- `management_min_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `1`)
- `management_max_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `3`)
- `services_instance_types`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `["m5.large"]`)
- `services_desired_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `2`)
- `services_min_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `2`)
- `services_max_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `5`)
- `data_instance_types`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `["r5.xlarge"]`)
- `data_desired_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `3`)
- `data_min_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `3`)
- `data_max_size`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: `5`)
- `tags`: `terragrunt/us-east-1/node-groups/terragrunt.hcl` (Value: Combines region/env tags)

Outputs:
--------
- `monitoring_node_group_id`: ID of the monitoring node group.
- `monitoring_node_group_arn`: ARN of the monitoring node group.
- `management_node_group_id`: ID of the management node group.
- `management_node_group_arn`: ARN of the management node group.
- `services_node_group_id`: ID of the services node group.
- `services_node_group_arn`: ARN of the services node group.
- `data_node_group_id`: ID of the data node group.
- `data_node_group_arn`: ARN of the data node group.
- `node_role_arn`: ARN of the common (`eks_node_role`) IAM role.
- `data_node_role_arn`: ARN of the data node (`eks_data_node_role`) IAM role.
- `node_role_name`: Name of the common (`eks_node_role`) IAM role.

Versioning: 
-----------
- None specified for components within this module.

Providers/Required providers:
------------------------------
- `hashicorp/aws`: `~> 5.0` (Locked version: `5.94.1`)

----------------
-"Module name": eks-addons-
----------------

Deployed components: 
--------------------
- `aws_iam_role.vpc_cni`: IAM role for the `aws-node` service account (VPC CNI) using IRSA.
- `aws_iam_role_policy_attachment.vpc_cni`: Attaches the `AmazonEKS_CNI_Policy` to the VPC CNI role.
- `aws_eks_addon.vpc_cni`: Installs/Manages the VPC CNI EKS addon, configured to use the IRSA role.
- `aws_eks_addon.coredns`: Installs/Manages the CoreDNS EKS addon.
- `aws_eks_addon.kube_proxy`: Installs/Manages the Kube Proxy EKS addon.
- `aws_iam_role.ebs_csi_driver`: IAM role for the `ebs-csi-controller-sa` service account (EBS CSI Driver) using IRSA.
- `aws_iam_role_policy_attachment.ebs_csi_driver`: Attaches the `AmazonEBSCSIDriverPolicy` to the EBS CSI Driver role.
- `aws_eks_addon.ebs_csi_driver`: Installs/Manages the AWS EBS CSI Driver EKS addon, configured to use the IRSA role.
- `aws_iam_policy.route53_dns_manager`: IAM policy granting permissions to manage Route53 records (used by ExternalDNS).
- `aws_iam_role.route53_dns_manager`: IAM role for the `external-dns` service account using IRSA.
- `aws_iam_role_policy_attachment.route53_dns_manager`: Attaches the Route53 policy to the ExternalDNS IRSA role.
- `kubernetes_service_account_v1.external_dns_sa`: Kubernetes service account (`external-dns` in `kube-system`) annotated with the IRSA role.
- `helm_release.external_dns`: Deploys ExternalDNS using the Bitnami Helm chart, configured to use the `external-dns` service account and target the specified domain.
- `kubectl_manifest.external_dns_netpol`: Applies a NetworkPolicy allowing required egress traffic for ExternalDNS (to K8s API, DNS, AWS APIs).

Hard coded vars:  
-----------------
- VPC CNI Addon Version: `"v1.19.3-eksbuild.1"` - `terraform/modules/eks-addons/main.tf`
- CoreDNS Addon Version: `"v1.11.4-eksbuild.2"` - `terraform/modules/eks-addons/main.tf`
- Kube Proxy Addon Version: `"v1.32.0-eksbuild.2"` - `terraform/modules/eks-addons/main.tf`
- EBS CSI Driver Addon Version: `"v1.41.0-eksbuild.1"` - `terraform/modules/eks-addons/main.tf`
- Addon Resolve Conflicts: `"OVERWRITE"` - `terraform/modules/eks-addons/main.tf`
- VPC CNI Service Account: `"system:serviceaccount:kube-system:aws-node"` - `terraform/modules/eks-addons/main.tf`
- EBS CSI Driver Service Account: `"system:serviceaccount:kube-system:ebs-csi-controller-sa"` - `terraform/modules/eks-addons/main.tf`
- Policy ARNs: `"arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"`, `"arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"` - `terraform/modules/eks-addons/main.tf`
- Route53 Policy Content: Defined in `locals.route53_dns_policy` - `terraform/modules/eks-addons/main.tf`
- ExternalDNS Helm Repository: `"oci://registry-1.docker.io/bitnamicharts"` - `terraform/modules/eks-addons/main.tf`
- ExternalDNS Helm Chart Name: `"external-dns"` - `terraform/modules/eks-addons/main.tf`
- ExternalDNS Helm Values: `provider: aws`, `zoneType: public`, `sources: [service, ingress]`, `policy: sync`, `rbac.create: true`, `rbac.pspEnabled: false`, `serviceAccount.create: false` - `terraform/modules/eks-addons/main.tf`
- Network Policy Labels/Selectors: `app.kubernetes.io/name: external-dns`, `k8s-app: kube-dns`, etc. - `terraform/modules/eks-addons/templates/external-dns-netpol.yaml`
- Role Name Patterns: `"${var.cluster_name}-vpc-cni-irsa"`, `"${var.cluster_name}-ebs-csi-driver-irsa"`, `"${var.cluster_name}-route53-dns-manager-irsa"` - `terraform/modules/eks-addons/main.tf`
- Policy Name Pattern: `"${var.cluster_name}-route53-dns-policy"` - `terraform/modules/eks-addons/main.tf`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `cluster_name`: `dependency.eks.outputs.cluster_name` (From `eks` module)
- `cluster_endpoint`: `dependency.eks.outputs.cluster_endpoint` (From `eks` module)
- `cluster_ca_cert`: `dependency.eks.outputs.cluster_certificate_authority_data` (From `eks` module)
- `aws_region`: `include.region.locals.aws_region` (From `region.hcl`)
- `tags`: `include.region.locals.tags` (From `region.hcl`)
- `cluster_oidc_provider_arn`: `dependency.eks.outputs.oidc_provider_arn` (From `eks` module)
- `create_route53_dns_manager_irsa`: `terragrunt/us-east-1/eks-addons/terragrunt.hcl` (Value: `true`)
- `external_dns_domain_filter`: `include.region.locals.domain_name` (From `region.hcl`)
- `external_dns_txt_owner_id`: `include.region.locals.cluster_name` (From `region.hcl`)
- `route53_dns_manager_namespace`: `terragrunt/us-east-1/eks-addons/terragrunt.hcl` (Value: `kube-system`)
- `route53_dns_manager_service_account`: `terragrunt/us-east-1/eks-addons/terragrunt.hcl` (Value: `external-dns`)
- `vpc_cni_version`: (Default: `""` - uses hardcoded version)
- `coredns_version`: (Default: `""` - uses hardcoded version)
- `kube_proxy_version`: (Default: `""` - uses hardcoded version)
- `ebs_csi_driver_version`: (Default: `""` - uses hardcoded version)
- `create_vpc_cni_irsa`: (Default: `true`)
- `create_ebs_csi_driver_irsa`: (Default: `true`)
- `external_dns_chart_version`: (Default: `"8.7.11"`)

Outputs:
--------
- `vpc_cni_addon_id`: ID of the VPC CNI EKS addon.
- `vpc_cni_version`: Installed version of the VPC CNI EKS addon.
- `vpc_cni_irsa_role_arn`: ARN of the IAM role for VPC CNI (if created).
- `coredns_addon_id`: ID of the CoreDNS EKS addon.
- `coredns_version`: Installed version of the CoreDNS EKS addon.
- `kube_proxy_addon_id`: ID of the Kube Proxy EKS addon.
- `kube_proxy_version`: Installed version of the Kube Proxy EKS addon.
- `ebs_csi_driver_addon_id`: ID of the EBS CSI Driver EKS addon.
- `ebs_csi_driver_version`: Installed version of the EBS CSI Driver EKS addon.
- `ebs_csi_driver_irsa_role_arn`: ARN of the IAM role for EBS CSI Driver (if created).
- `route53_dns_manager_irsa_role_arn`: ARN of the IAM role for ExternalDNS (if created).
- `route53_dns_manager_policy_arn`: ARN of the IAM policy for ExternalDNS (if created).
- `external_dns_helm_release_status`: Status of the ExternalDNS Helm release (if created).

Versioning: 
-----------
- EKS Addons: `vpc-cni=v1.19.3-eksbuild.1`, `coredns=v1.11.4-eksbuild.2`, `kube-proxy=v1.32.0-eksbuild.2`, `aws-ebs-csi-driver=v1.41.0-eksbuild.1`
- ExternalDNS Helm Chart: `8.7.11`

Providers/Required providers:
------------------------------
- `hashicorp/aws`: `~> 5.94` (Locked version: `5.94.1`)
- `hashicorp/kubernetes`: `~> 2.36` (Locked version: `2.36.0`)
- `hashicorp/helm`: `~> 2.17` (Locked version: `2.17.0`)
- `gavinbunney/kubectl`: `~> 1.19` (Locked version: `1.19.0`)

----------------
-"Module name": namespaces-
----------------

Deployed components: 
--------------------
- `kubernetes_namespace` (monitoring): Creates the `monitoring` namespace.
- `kubernetes_namespace` (data): Creates the `data` namespace.
- `kubernetes_namespace` (logging): Creates the `logging` namespace.
- `kubernetes_namespace` (security): Creates the `security` namespace.
- `kubernetes_namespace` (argocd): Creates the `argocd` namespace.
- `kubernetes_namespace` (app): Creates the `app` namespace.

Hard coded vars:  
-----------------
- Namespace Names: `monitoring`, `data`, `logging`, `security`, `argocd`, `app` - `terraform/modules/namespaces/main.tf`
- Namespace Labels: `{"name": "..."}` - `terraform/modules/namespaces/main.tf`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `cluster_name`: `dependency.eks.outputs.cluster_name` (From `eks` module)
- `cluster_endpoint`: `dependency.eks.outputs.cluster_endpoint` (From `eks` module)
- `cluster_certificate_authority_data`: `dependency.eks.outputs.cluster_certificate_authority_data` (From `eks` module)
- `aws_region`: `include.region.locals.aws_region` (From `region.hcl`)
- `tags`: `include.region.locals.tags` (From `region.hcl`)

Outputs:
--------
- None.

Versioning: 
-----------
- None specified.

Providers/Required providers:
------------------------------
- `hashicorp/kubernetes`: `~> 2.36` (Locked version: `2.36.0`)
- `gavinbunney/kubectl`: `~> 1.19` (Locked version: `1.19.0`)
- *Note*: Kubernetes and Helm providers are configured dynamically via the `generate` block in `terragrunt/us-east-1/namespaces/terragrunt.hcl` using outputs from the `eks` dependency.

----------------
-"Module name": external-secrets-
----------------

Deployed components: 
--------------------
- `aws_iam_role.external_secrets`: IAM role for the `external-secrets` service account using IRSA.
- `aws_iam_policy.external_secrets`: IAM policy granting permissions to access specific secrets/parameters in Secrets Manager and SSM Parameter Store based on prefixes.
- `aws_iam_role_policy_attachment.external_secrets`: Attaches the main policy to the External Secrets IRSA role.
- `aws_iam_policy.mysql_secret_access`: Specific IAM policy granting permissions to access MySQL-related secrets in Secrets Manager.
- `aws_iam_role_policy_attachment.mysql_secret_access`: Attaches the MySQL policy to the External Secrets IRSA role.
- `helm_release.external_secrets`: Deploys the External Secrets Operator using its Helm chart.
- `kubectl_manifest.secretstore`: Creates a `ClusterSecretStore` resource named `aws-secretsmanager` pointing to AWS Secrets Manager and using the IRSA role.
- `random_string`: Resources to generate random suffixes for AWS secret names to ensure uniqueness on re-creation.
- `aws_secretsmanager_secret`: Creates secrets in AWS Secrets Manager for MySQL app user, MySQL root, Weather API key, Slack webhook URL, and Grafana admin credentials. Uses random suffixes and a defined prefix (`eks-blizzard`). Tagged with `status=active`.
- `random_password`: Resources to generate random passwords for MySQL app user, MySQL root, and Grafana admin.
- `aws_secretsmanager_secret_version`: Creates initial versions for the Secrets Manager secrets with generated or provided values.
- `null_resource`: Resources (`*_tag_cleanup`) that run a `local-exec` provisioner on destroy to update the corresponding AWS secret's `status` tag to `inactive`.
- `kubernetes_secret_v1` (mysql_root_k8s_secret): Creates a Kubernetes secret (`mysql-root-credential` in `data` ns) containing the generated MySQL root password.
- `kubernetes_secret_v1` (mysql_app_k8s_secret): Creates a Kubernetes secret (`mysql-app-credential` in `data` ns) containing the generated MySQL app user credentials (username, password, database).
- `kubernetes_secret_v1` (grafana_admin_k8s_secret): Creates a Kubernetes secret (`grafana-admin-credentials` in `monitoring` ns) containing the generated Grafana admin credentials.
- `kubernetes_secret_v1` (slack_webhook_k8s_secret): Creates a Kubernetes secret (`alertmanager-slack-webhook` in `monitoring` ns) containing the Slack webhook URL (only if provided).
- `kubernetes_secret_v1` (weather_api_k8s_secret): Creates a Kubernetes secret (`weather-api-key` in `app` ns) containing the Weather API key (only if provided).
- `kubernetes_secret_v1` (mysql_app_k8s_secret_for_app): Creates a duplicate Kubernetes secret (`mysql-app-credentials` in `app` ns) containing the MySQL app user credentials.

Hard coded vars:  
-----------------
- Service Account Name: `"external-secrets"` (in IRSA policy condition and SecretStore) - `terraform/modules/external-secrets/main.tf`, `templates/secretstore.yaml`
- SecretStore Name: `"aws-secretsmanager"` - `terraform/modules/external-secrets/main.tf`
- Secret Name Prefix: `"eks-blizzard"` - `terraform/modules/external-secrets/variables.tf` (default)
- Parameter Store Prefix: `"eks-blizzard"` - `terraform/modules/external-secrets/variables.tf` (default)
- Random String Length: `6` - `terraform/modules/external-secrets/main.tf`
- Password Length: `16` - `terraform/modules/external-secrets/main.tf`
- Password Special Chars: `false` (mysql app user), `true` (mysql root, grafana admin) - `terraform/modules/external-secrets/main.tf`
- Secret Tags: `status=active`, `status=inactive` - `terraform/modules/external-secrets/main.tf`
- MySQL Default User: `"app_user"` - `terraform/modules/external-secrets/variables.tf` (default)
- MySQL Default Database: `"app_db"` - `terraform/modules/external-secrets/variables.tf` (default)
- Grafana Default User: `"admin"` - `terraform/modules/external-secrets/main.tf`
- K8s Secret Names: `mysql-root-credential`, `mysql-app-credential`, `grafana-admin-credentials`, `alertmanager-slack-webhook`, `weather-api-key`, `mysql-app-credentials` - `terraform/modules/external-secrets/variables.tf` (defaults)
- K8s Secret Keys: `password`, `username`, `database`, `api-key`, `webhookUrl`, `admin-user`, `admin-password` - `terraform/modules/external-secrets/main.tf`
- K8s Secret Namespaces: `data`, `monitoring`, `app` - `terraform/modules/external-secrets/variables.tf` (defaults)
- Base64 Encoding: Used for some K8s secret values (`password`, `admin-user`, `admin-password`, `slack_webhook_url`) - `terraform/modules/external-secrets/main.tf`
- Local Exec Commands: `aws secretsmanager tag-resource ...` - `terraform/modules/external-secrets/main.tf`
- External Secrets Helm Repo: `"https://charts.external-secrets.io"` - `terraform/modules/external-secrets/main.tf`
- External Secrets Chart Name: `"external-secrets"` - `terraform/modules/external-secrets/main.tf`
- Role Name Pattern: `"${var.cluster_name}-external-secrets"` - `terraform/modules/external-secrets/main.tf`
- Policy Name Pattern: `"${var.cluster_name}-external-secrets"`, `"${var.cluster_name}-mysql-secret-access"` - `terraform/modules/external-secrets/main.tf`, `mysql-policy.tf`

Required env vars:
-------------------
- `TF_VAR_slack_webhook_url`: Used via `get_env` in `terragrunt.hcl` to populate `slack_webhook_url` input (if not empty).
- `TF_VAR_weather_api_key`: Used via `get_env` in `terragrunt.hcl` to populate `weather_api_key` input (if not empty).

Inputs: 
-------
- `cluster_name`: `dependency.eks.outputs.cluster_name` (From `eks` module)
- `aws_region`: `include.region.locals.aws_region` (From `region.hcl`)
- `account_id`: `get_aws_account_id()` (Function call in `terragrunt.hcl`)
- `oidc_provider`: `dependency.eks.outputs.oidc_provider_url` (From `eks` module)
- `oidc_provider_arn`: `dependency.eks.outputs.oidc_provider_arn` (From `eks` module)
- `slack_webhook_url`: `get_env("TF_VAR_slack_webhook_url", "")` (From env var, via `terragrunt.hcl`)
- `weather_api_key`: `get_env("TF_VAR_weather_api_key", "")` (From env var, via `terragrunt.hcl`)
- `tags`: `include.region.locals.tags` (From `region.hcl`)
- `secret_prefix`: (Default: `eks-blizzard`)
- `parameter_prefix`: (Default: `eks-blizzard`)
- `chart_version`: (Default: `0.15.1`)
- `mysql_password`: (Default: `""`)
- `generate_random_password`: (Default: `true`)
- `mysql_app_user`: (Default: `app_user`)
- `mysql_app_database`: (Default: `app_db`)
- `data_namespace`: (Default: `data`)
- `k8s_root_secret_name`: (Default: `mysql-root-credential`)
- `k8s_app_secret_name`: (Default: `mysql-app-credential`)
- `monitoring_namespace`: (Default: `monitoring`)
- `k8s_grafana_secret_name`: (Default: `grafana-admin-credentials`)
- `k8s_slack_secret_name`: (Default: `alertmanager-slack-webhook`)
- `app_namespace`: (Default: `app`)
- `k8s_weather_secret_name`: (Default: `weather-api-key`)
- `k8s_app_mysql_secret_name`: (Default: `mysql-app-credentials`)

Outputs:
--------
- `secretstore_name`: Name of the ClusterSecretStore (`aws-secretsmanager`).
- `external_secrets_role_arn`: ARN of the External Secrets Operator IAM role.
- `mysql_app_user_secret_name`: Name of the MySQL app user secret in AWS Secrets Manager.
- `mysql_app_user_password`: Generated MySQL app user password.
- `mysql_root_secret_name`: Name of the MySQL root secret in AWS Secrets Manager.
- `weather_api_secret_name`: Name of the Weather API secret in AWS Secrets Manager.
- `slack_webhook_secret_name`: Name of the Slack webhook secret in AWS Secrets Manager.
- `grafana_admin_secret_name`: Name of the Grafana admin secret in AWS Secrets Manager.

Versioning: 
-----------
- External Secrets Helm Chart: `0.15.1`

Providers/Required providers:
------------------------------
- `hashicorp/aws`: `~> 5.94` (Locked version: `5.94.1`)
- `hashicorp/kubernetes`: `~> 2.36` (Locked version: `2.36.0`)
- `hashicorp/helm`: `~> 2.17` (Locked version: `2.17.0`)
- `gavinbunney/kubectl`: `~> 1.19` (Locked version: `1.19.0`)
- `hashicorp/random`: `~> 3.7.1` (Locked version: `3.7.1`)
- `hashicorp/null`: `~> 3.2.3` (Locked version: `3.2.3`)
- *Note*: Providers (kubernetes, helm, kubectl) are configured dynamically via the `generate` block in `terragrunt/us-east-1/external-secrets/terragrunt.hcl` using outputs from the `eks` dependency.

----------------
-"Module name": argocd-
----------------

Deployed components: 
--------------------
- `aws_iam_role.load_balancer_controller`: IAM role for the AWS Load Balancer Controller service account (`aws-load-balancer-controller` in `kube-system`) using IRSA.
- `aws_iam_policy.load_balancer_controller`: IAM policy containing permissions required by the AWS Load Balancer Controller (defined in `policies/aws-load-balancer-controller-policy.json`).
- `aws_iam_role_policy_attachment.load_balancer_controller`: Attaches the policy to the LB controller role.
- `helm_release.aws_load_balancer_controller`: Deploys the AWS Load Balancer Controller using its Helm chart, configured with the cluster name, region, VPC ID, and IRSA role. Runs on management nodes.
- `helm_release.argocd`: Deploys Argo CD using the official Helm chart, configured to run on management nodes and disabling its built-in ingress.
- `kubernetes_ingress_v1.argocd_ingress`: Creates a Kubernetes Ingress resource specifically for Argo CD, using the AWS Load Balancer Controller (`ingress.class=alb`), configured for internet-facing scheme, ACM certificate, and routing traffic to the `argocd-server` service.
- `time_sleep.wait_after_ingress`: Pauses execution for 30 seconds after creating the ingress to allow time for the LB controller to provision the ALB.
- `data.kubernetes_secret.argocd_initial_admin_password`: Reads the initial admin password secret created by the Argo CD Helm chart.
- `kubectl_manifest.applicationset`: Creates Argo CD ApplicationSet resources based on the `application_sets` input variable, defining how applications (monitoring, app, mysql, elasticsearch, fluentd) are deployed and managed via GitOps.

Hard coded vars:  
-----------------
- LB Controller SA Name: `"system:serviceaccount:kube-system:aws-load-balancer-controller"` (in IRSA policy) - `terraform/modules/argocd/main.tf`
- LB Controller Policy File Path: `"${path.module}/policies/aws-load-balancer-controller-policy.json"` - `terraform/modules/argocd/main.tf`
- LB Controller Helm Repo/Chart: `"https://aws.github.io/eks-charts"`, `"aws-load-balancer-controller"` - `terraform/modules/argocd/main.tf`
- ArgoCD Helm Repo/Chart: `"https://argoproj.github.io/argo-helm"`, `"argo-cd"` - `terraform/modules/argocd/main.tf`
- ArgoCD Ingress Annotations: `"kubernetes.io/ingress.class": "alb"`, `"alb.ingress.kubernetes.io/scheme": "internet-facing"`, etc. - `terraform/modules/argocd/main.tf`
- ArgoCD Ingress Backend Service/Port: `"argocd-server"`, `80` - `terraform/modules/argocd/main.tf`
- Sleep Duration: `"30s"` - `terraform/modules/argocd/main.tf`
- Initial Admin Secret Name: `"argocd-initial-admin-secret"` - `terraform/modules/argocd/main.tf`
- ApplicationSet Spec Defaults: `project: default`, `server: https://kubernetes.default.svc`, `syncOptions: [CreateNamespace=true, PrunePropagationPolicy=foreground, PruneLast=true]` - `terraform/modules/argocd/templates/applicationset.yaml`
- ArgoCD `values.yaml` settings: `server.extraArgs: [--insecure]`, `configs.params.server.insecure: true`, `configManagementPlugins`, `resourceCustomizations`, etc. - `terraform/modules/argocd/templates/values.yaml`
- Role Name Pattern: `"${var.cluster_name}-lb-controller-role"` - `terraform/modules/argocd/main.tf`
- Policy Name Pattern: `"${var.cluster_name}-lb-controller-policy"` - `terraform/modules/argocd/main.tf`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `aws_region`: `include.region.locals.aws_region` (From `region.hcl`)
- `cluster_name`: `dependency.eks.outputs.cluster_name` (From `eks` module)
- `vpc_id`: `dependency.vpc.outputs.vpc_id` (From `networking` module)
- `cluster_endpoint`: `dependency.eks.outputs.cluster_endpoint` (From `eks` module)
- `cluster_certificate_authority_data`: `dependency.eks.outputs.cluster_certificate_authority_data` (From `eks` module)
- `cluster_oidc_provider_arn`: `dependency.eks.outputs.oidc_provider_arn` (From `eks` module)
- `namespace`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (Value: `argocd`)
- `argocd_helm_chart_version`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (Value: `7.8.23`)
- `ingress_enabled`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (Value: `true`)
- `ingress_host`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (Value: `argocd-${include.region.locals.aws_region}.${include.region.locals.domain_name}`)
- `ingress_tls_secret`: `include.region.locals.acm_certificate_arn` (From `region.hcl`)
- `service_type`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (Value: `ClusterIP`)
- `node_selector`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (Value: `{"node-role": "management"}`)
- `toleration_key`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (Value: `management`)
- `toleration_value`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (Value: `true`)
- `toleration_effect`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (Value: `NoSchedule`)
- `application_sets`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (List of objects defining appsets for monitoring, app, mysql, elasticsearch, fluentd, with values from dependencies and `region.hcl`)
- `tags`: `terragrunt/us-east-1/argocd/terragrunt.hcl` (Combines region/env tags)
- `lb_controller_helm_chart_version`: (Default: `1.12.0`)

Outputs:
--------
- `deploy_complete`: Dummy output, value `true`.
- `argocd_namespace`: Namespace where Argo CD is deployed (`argocd`).
- `argocd_server_service`: Service name of the Argo CD server (`argocd-server`).
- `argocd_initial_admin_password`: Initial admin password retrieved from the K8s secret.
- `lb_controller_role_arn`: ARN of the IAM role used by the AWS Load Balancer Controller.
- `argocd_ingress_hostname`: Hostname where Argo CD is accessible via ingress.
- `argocd_ingress_created`: The ID of the created Argo CD Kubernetes Ingress resource.

Versioning: 
-----------
- Argo CD Helm Chart: `7.8.23`
- AWS Load Balancer Controller Helm Chart: `1.12.0`

Providers/Required providers:
------------------------------
- `hashicorp/aws`: `~> 5.94` (Locked version: `5.94.1`)
- `hashicorp/kubernetes`: `~> 2.36` (Locked version: `2.36.0`)
- `hashicorp/helm`: `~> 2.17` (Locked version: `2.17.0`)
- `gavinbunney/kubectl`: `~> 1.19` (Locked version: `1.19.0`)
- `hashicorp/time`: `~> 0.13` (Locked version: `0.13.0`)

----------------
-"Module name": karpenter-
----------------

Deployed components: 
--------------------
- `aws_iam_role.karpenter_controller`: IAM role for the Karpenter controller service account (`karpenter-controller` in `karpenter` ns) using IRSA.
- `aws_iam_policy.karpenter_controller`: IAM policy granting permissions required by Karpenter to manage EC2 instances (CreateLaunchTemplate, CreateFleet, RunInstances, TerminateInstances, Describe*, PassRole, etc.).
- `aws_iam_role_policy_attachment.karpenter_controller`: Attaches the policy to the Karpenter controller role.
- `helm_release.karpenter`: Deploys Karpenter using its official Helm chart from the ECR OCI registry, configured with cluster details, IRSA role, and node placement settings (management nodes).
- `time_sleep.wait_for_karpenter_crds`: Pauses execution for 30 seconds after Karpenter Helm release to allow CRDs to become available.
- `kubectl_manifest.karpenter_provisioner`: Applies Karpenter custom resources (`NodePool`, `EC2NodeClass`) to define how Karpenter should provision new nodes (instance types, AZs, capacity types, AMI family, node role, subnets, security groups, EBS settings).

Hard coded vars:  
-----------------
- Service Account Name: `"system:serviceaccount:karpenter:karpenter-controller"` (in IRSA policy) - `terraform/modules/karpenter/main.tf`
- IAM Policy Actions: `["ec2:CreateLaunchTemplate", "ec2:CreateFleet", ...]` - `terraform/modules/karpenter/main.tf`
- Helm Repository: `"oci://public.ecr.aws/karpenter"` - `terraform/modules/karpenter/main.tf`
- Helm Chart Name: `"karpenter"` - `terraform/modules/karpenter/main.tf`
- Namespace: `"karpenter"` - `terraform/modules/karpenter/main.tf`
- Sleep Duration: `"30s"` - `terraform/modules/karpenter/main.tf`
- NodePool Name: `"default"` - `terraform/modules/karpenter/templates/nodepool.yaml`
- NodePool Labels: `{"provisioning-group": "karpenter", "node-role": "services"}` - `terraform/modules/karpenter/templates/nodepool.yaml`
- NodePool Requirements: Instance types (`m5.large`, etc.), Zones (`${region}a`, etc.), Arch (`amd64`), Capacity Type (`on-demand`, `spot`) - `terraform/modules/karpenter/templates/nodepool.yaml`
- NodePool Disruption: `consolidationPolicy: WhenEmptyOrUnderutilized`, `consolidateAfter: 30s`, `expireAfter: 12h` - `terraform/modules/karpenter/templates/nodepool.yaml`
- NodePool Limits: `cpu: 100`, `memory: 200Gi` - `terraform/modules/karpenter/templates/nodepool.yaml`
- EC2NodeClass Name: `"default"` - `terraform/modules/karpenter/templates/nodepool.yaml`
- EC2NodeClass AMI Family: `"AL2"` - `terraform/modules/karpenter/templates/nodepool.yaml`
- EC2NodeClass Subnet Selector: `tags: { karpenter.sh/discovery: ${cluster_name}, Type: Private }` - `terraform/modules/karpenter/templates/nodepool.yaml`
- EC2NodeClass Security Group Selector: `tags: { karpenter.sh/discovery: ${cluster_name}, kubernetes.io/cluster/${cluster_name}: owned }` - `terraform/modules/karpenter/templates/nodepool.yaml`
- EC2NodeClass Tags: `karpenter.sh/discovery: ${cluster_name}`, `created-by: karpenter` - `terraform/modules/karpenter/templates/nodepool.yaml`
- EC2NodeClass EBS Settings: `deviceName: /dev/xvda`, `volumeSize: 50Gi`, `volumeType: gp3`, `iops: 3000`, `encrypted: true` - `terraform/modules/karpenter/templates/nodepool.yaml`
- Controller Resource Requests/Limits: `200m`/`256Mi`, `1`/`1Gi` - `terraform/modules/karpenter/main.tf`
- Role Name Pattern: `"${var.cluster_name}-karpenter-controller"` - `terraform/modules/karpenter/main.tf`
- Policy Name Pattern: `"${var.cluster_name}-karpenter-controller"` - `terraform/modules/karpenter/main.tf`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `cluster_name`: `dependency.eks.outputs.cluster_name` (From `eks` module)
- `cluster_arn`: `dependency.eks.outputs.cluster_arn` (From `eks` module)
- `cluster_endpoint`: `dependency.eks.outputs.cluster_endpoint` (From `eks` module)
- `cluster_certificate_authority_data`: `dependency.eks.outputs.cluster_certificate_authority_data` (From `eks` module)
- `oidc_provider`: `dependency.eks.outputs.oidc_provider_url` (From `eks` module)
- `oidc_provider_arn`: `dependency.eks.outputs.oidc_provider_arn` (From `eks` module)
- `node_iam_role_arn`: `dependency.node_groups.outputs.node_role_arn` (From `node-groups` module)
- `node_role_name`: `dependency.node_groups.outputs.node_role_name` (From `node-groups` module)
- `private_subnet_ids`: `dependency.vpc.outputs.private_subnets` (From `networking` module)
- `security_group_ids`: `[dependency.eks.outputs.cluster_security_group_id]` (From `eks` module)
- `aws_region`: `include.region.locals.aws_region` (From `region.hcl`)
- `tags`: `include.region.locals.tags` (From `region.hcl`)
- `karpenter_chart_version`: (Default: `1.3.2`)

Outputs:
--------
- None defined in `outputs.tf`.

Versioning: 
-----------
- Karpenter Helm Chart: `1.3.2`

Providers/Required providers:
------------------------------
- `hashicorp/aws`: `~> 5.94` (Locked version: `5.94.1`)
- `hashicorp/kubernetes`: `~> 2.36` (Locked version: `2.36.0`)
- `hashicorp/helm`: `~> 2.17` (Locked version: `2.17.0`)
- `gavinbunney/kubectl`: `~> 1.19` (Locked version: `1.19.0`)
- `hashicorp/time`: `~> 0.13` (Locked version: `0.13.0`)

----------------
-"Module name": keda-
----------------

Deployed components: 
--------------------
- `aws_iam_role.keda_controller`: IAM role for the KEDA operator service account (`keda-operator` in `keda` ns) using IRSA.
- `aws_iam_policy.keda_controller`: IAM policy granting CloudWatch permissions (`GetMetricData`, `ListMetrics`, `DescribeAlarms`) needed by KEDA scalers.
- `aws_iam_role_policy_attachment.keda_controller`: Attaches the CloudWatch policy to the KEDA controller role.
- `helm_release.keda`: Deploys KEDA (Kubernetes Event-driven Autoscaling) using its official Helm chart, configured with the IRSA role and placed on management nodes.
- `kubectl_manifest.keda_scaled_object`: Creates a KEDA `ScaledObject` resource (`app-scaler`) targeting the specified application deployment (`weather-app` in `app` ns), configured to scale based on a Prometheus metric (`http_requests_per_second`).

Hard coded vars:  
-----------------
- Service Account Name: `"system:serviceaccount:keda:keda-operator"` (in IRSA policy) - `terraform/modules/keda/main.tf`
- IAM Policy Actions: `["cloudwatch:GetMetricData", "cloudwatch:ListMetrics", "cloudwatch:DescribeAlarms"]` - `terraform/modules/keda/main.tf`
- Helm Repository: `"https://kedacore.github.io/charts"` - `terraform/modules/keda/main.tf`
- Helm Chart Name: `"keda"` - `terraform/modules/keda/main.tf`
- Namespace: `"keda"` - `terraform/modules/keda/main.tf`
- ScaledObject Name: `"app-scaler"` - `terraform/modules/keda/main.tf`
- ScaledObject Polling Interval: `15` seconds - `terraform/modules/keda/templates/scaled-object.yaml`
- ScaledObject Cooldown Period: `60` seconds - `terraform/modules/keda/templates/scaled-object.yaml`
- ScaledObject Trigger Type: `"prometheus"` - `terraform/modules/keda/templates/scaled-object.yaml`
- ScaledObject Metric Name: `"http_requests_per_second"` - `terraform/modules/keda/templates/scaled-object.yaml`
- ScaledObject Threshold: `'10'` - `terraform/modules/keda/templates/scaled-object.yaml`
- ScaledObject Query: `sum(rate(http_requests_total{app="${deployment_name}"}[5m]))` - `terraform/modules/keda/templates/scaled-object.yaml`
- `values.yaml` Settings: `podSecurityContext`, `resources`, `affinity`, `tolerations`, `metricsServer.rbac.create`, `prometheus.metricServer.enabled` - `terraform/modules/keda/templates/values.yaml`
- Role Name Pattern: `"${var.cluster_name}-keda-controller"` - `terraform/modules/keda/main.tf`
- Policy Name Pattern: `"${var.cluster_name}-keda-controller"` - `terraform/modules/keda/main.tf`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `aws_region`: `include.region.locals.aws_region` (From `region.hcl`)
- `cluster_name`: `dependency.eks.outputs.cluster_name` (From `eks` module)
- `cluster_endpoint`: `dependency.eks.outputs.cluster_endpoint` (From `eks` module)
- `cluster_certificate_authority_data`: `dependency.eks.outputs.cluster_certificate_authority_data` (From `eks` module)
- `oidc_provider`: `dependency.eks.outputs.oidc_provider_url` (From `eks` module)
- `oidc_provider_arn`: `dependency.eks.outputs.oidc_provider_arn` (From `eks` module)
- `app_deployment_name`: `terragrunt/us-east-1/keda/terragrunt.hcl` (Value: `weather-app`)
- `app_namespace`: `terragrunt/us-east-1/keda/terragrunt.hcl` (Value: `app`)
- `prometheus_url`: `terragrunt/us-east-1/keda/terragrunt.hcl` (Value: `http://prometheus-server.monitoring:9090`)
- `tags`: `include.region.locals.tags` (From `region.hcl`)
- `keda_chart_version`: (Default: `2.16.0`)

Outputs:
--------
- None defined in `outputs.tf`.

Versioning: 
-----------
- KEDA Helm Chart: `2.16.0`

Providers/Required providers:
------------------------------
- `hashicorp/aws`: `~> 5.0` (Locked version: `5.94.1`)
- `hashicorp/kubernetes`: `~> 2.20` (Locked version: `2.36.0`)
- `hashicorp/helm`: `~> 2.10` (Locked version: `2.17.0`)
- `gavinbunney/kubectl`: `~> 1.14` (Locked version: `1.19.0`)

----------------
-"Module name": trivy-operator-
----------------

Deployed components: 
--------------------
- `kubernetes_namespace.trivy_ns`: Creates the namespace (`trivy-system`) for Trivy Operator if it doesn't exist.
- `aws_iam_role.trivy_operator`: IAM role for the Trivy Operator service account (`trivy-operator` in `trivy-system` ns) using IRSA. (Minimal policy attached by default).
- `helm_release.trivy_operator`: Deploys the Trivy Operator using the official Aqua Security Helm chart, configured with the IRSA role and node placement settings (management nodes). It enables various scanners (vulnerability, config audit, RBAC, infra, secrets, compliance) and configures Prometheus ServiceMonitor integration.

Hard coded vars:  
-----------------
- Service Account Condition: `"system:serviceaccount:${var.trivy_namespace}:${var.trivy_service_account_name}"` (in IRSA policy) - `terraform/modules/trivy-operator/main.tf`
- Helm Repository: `"https://aquasecurity.github.io/helm-charts/"` - `terraform/modules/trivy-operator/main.tf`
- Helm Chart Name: `"trivy-operator"` - `terraform/modules/trivy-operator/main.tf`
- `values.yaml` Settings: `serviceAccount.create: true`, `operator.replicas: 1`, scanners enabled (`vulnerabilityScannerEnabled: true`, etc.), `operator.resources`, `nodeCollector.tolerations`, `trivyOperator.scanJobNodeSelector: {}`, `trivyOperator.scanJobTolerations`, `trivyOperator.reportRecordFailedChecksOnly: true`, `trivy.ignoreUnfixed: true`, `trivy.severity: "CRITICAL,HIGH"`, `rbac.create: true`, `prometheus.enabled: false`, `prometheus.serviceMonitor.enabled: true` - `terraform/modules/trivy-operator/templates/values.yaml`
- Role Name Pattern: `"${var.cluster_name}-trivy-operator-irsa"` - `terraform/modules/trivy-operator/main.tf`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `cluster_name`: `dependency.eks.outputs.cluster_name` (From `eks` module)
- `cluster_endpoint`: `dependency.eks.outputs.cluster_endpoint` (From `eks` module)
- `cluster_certificate_authority_data`: `dependency.eks.outputs.cluster_certificate_authority_data` (From `eks` module)
- `cluster_oidc_provider_arn`: `dependency.eks.outputs.oidc_provider_arn` (From `eks` module)
- `aws_region`: `include.region.locals.aws_region` (From `region.hcl`)
- `tags`: `include.region.locals.tags` (From `region.hcl`)
- `trivy_namespace`: `terragrunt/us-east-1/trivy-operator/terragrunt.hcl` (Value: `trivy-system`)
- `trivy_service_account_name`: `terragrunt/us-east-1/trivy-operator/terragrunt.hcl` (Value: `trivy-operator`)
- `trivy_helm_chart_version`: `terragrunt/us-east-1/trivy-operator/terragrunt.hcl` (Value: `0.27.0`)
- `management_node_selector`: `terragrunt/us-east-1/trivy-operator/terragrunt.hcl` (Value: `{"node-role": "management"}`)
- `management_tolerations`: `terragrunt/us-east-1/trivy-operator/terragrunt.hcl` (Value: `[{key="management", operator="Equal", value="true", effect="NoSchedule"}]`)

Outputs:
--------
- None defined in `outputs.tf`.

Versioning: 
-----------
- Trivy Operator Helm Chart: `0.27.0`

Providers/Required providers:
------------------------------
- `hashicorp/aws`: `~> 5.0` (Locked version: `5.94.1`)
- `hashicorp/kubernetes`: `~> 2.20` (Locked version: `2.36.0`)
- `hashicorp/helm`: `~> 2.10` (Locked version: `2.17.0`)
- `gavinbunney/kubectl`: `~> 1.14` (Locked version: `1.19.0`)

----------------
-"Module name": network-policies-
----------------

Deployed components: 
--------------------
- `kubectl_manifest` (for each namespace + policy): Applies Kubernetes `NetworkPolicy` resources based on YAML templates stored in the `templates/` directory. This includes:
    - Default deny-all ingress/egress policies for most namespaces (`default-deny.yaml`).
    - Policies allowing DNS egress (`allow-dns.yaml`).
    - Specific ingress/egress policies for inter-component communication (e.g., `app-to-mysql.yaml`, `fluentd-to-elasticsearch.yaml`, `prometheus-to-targets.yaml`, `keda-to-prometheus.yaml`, `allow-prometheus-to-trivy.yaml`, `allow-ingress-to-app.yaml`).
    - Specific egress policies for external communication (e.g., `external-secrets-egress.yaml`, `allow-app-egress-internet.yaml`, `allow-grafana-egress.yaml`, `allow-alertmanager-egress.yaml`, `allow-karpenter-egress.yaml`, `allow-argocd-egress.yaml`, `allow-api-egress.yaml`, `allow-internet-egress.yaml`).
    - Policies for internal component communication (e.g., `allow-elasticsearch-inter-node.yaml`).

Hard coded vars:  
-----------------
- All NetworkPolicy definitions (selectors, ports, namespaces, CIDRs, policy types) within the YAML files in `terraform/modules/network-policies/templates/`.
- Namespace Names: `"default"`, `"monitoring"`, `"keda"`, `"argocd"`, `"external-secrets"`, `"data"`, `"logging"`, `"karpenter"`, `"security"`, `"trivy-system"` - `terraform/modules/network-policies/main.tf` and templates.
- Pod/Namespace Labels used in selectors (e.g., `app: prometheus`, `app.kubernetes.io/name: keda-operator`, `kubernetes.io/metadata.name: monitoring`, `k8s-app: kube-dns`, etc.) - `terraform/modules/network-policies/templates/*.yaml`
- Ports used in policies (e.g., 53, 443, 80, 9090, 3306, 9200, 9300, 8080, 5000, 9100, 9104, 9114) - `terraform/modules/network-policies/templates/*.yaml`
- CIDR Blocks: `0.0.0.0/0`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` - `terraform/modules/network-policies/templates/*.yaml`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `cluster_name`: `dependency.eks.outputs.cluster_name` (From `eks` module)
- `aws_region`: `include.region.locals.aws_region` (From `region.hcl`)
- `tags`: `include.region.locals.tags` (From `region.hcl`)

Outputs:
--------
- None defined in `outputs.tf`.

Versioning: 
-----------
- None specified.

Providers/Required providers:
------------------------------
- `hashicorp/kubernetes`: `~> 2.36` (Locked version: `2.36.0`)
- `gavinbunney/kubectl`: `~> 1.19` (Locked version: `1.19.0`)

----------------
-"Module name": security-policies-
----------------

Deployed components: 
--------------------
- `helm_release.polaris`: Deploys the Polaris policy engine using its Helm chart, configured to run the dashboard on management nodes. Webhook and audit modes are disabled by default.
- `kubernetes_role_v1.argocd_external_secret_manager_data`: Creates a Kubernetes Role in the `data` namespace granting permissions to manage `ExternalSecret` resources.
- `kubernetes_role_binding_v1.argocd_external_secret_manager_data`: Binds the above Role to the Argo CD Application Controller service account (`argocd-application-controller` in `argocd` ns), allowing Argo CD to manage ExternalSecrets specifically within the `data` namespace.
- `kubernetes_role_v1.data_secret_reader`: Creates a Kubernetes Role in the `data` namespace granting permissions to read (`get`, `watch`, `list`) Kubernetes Secrets.
- `kubernetes_service_account_v1.mysql_sa`: Creates a Kubernetes Service Account named `mysql-sa` in the `data` namespace.
- `kubernetes_role_binding_v1.mysql_sa_secret_reader_binding`: Binds the `secret-reader` Role to the `mysql-sa` Service Account, allowing pods using this service account to read secrets within the `data` namespace.

Hard coded vars:  
-----------------
- Polaris Helm Repository: `"https://charts.fairwinds.com/stable"` - `terraform/modules/security-policies/main.tf`
- Polaris Helm Chart Name: `"polaris"` - `terraform/modules/security-policies/main.tf`
- Polaris Namespace: `"security"` - `terraform/modules/security-policies/main.tf`
- Polaris `values.yaml` Settings: `crds.create: false`, `dashboard.enable: true`, `webhook.enable: false`, `audit.enable: false`, checks configuration (`readinessProbeMissing: danger`, etc.) - `terraform/modules/security-policies/main.tf`, `templates/polaris-values.yaml`
- RBAC Resource Names: `"argocd-external-secret-manager"`, `"secret-reader"`, `"mysql-sa"`, `"mysql-sa-secret-reader-binding"` - `terraform/modules/security-policies/main.tf`
- RBAC Namespaces: `"data"`, `"argocd"` - `terraform/modules/security-policies/main.tf`
- RBAC API Groups/Resources/Verbs: `external-secrets.io/externalsecrets`, `""/secrets`, `["get", "list", "watch", ...]` - `terraform/modules/security-policies/main.tf`
- RBAC Service Account Subject: `"argocd-application-controller"` in `argocd` ns - `terraform/modules/security-policies/main.tf`
- RBAC Labels: `{"app.kubernetes.io/part-of": "argocd"}` - `terraform/modules/security-policies/main.tf`

Required env vars:
-------------------
- None identified for this specific module.

Inputs: 
-------
- `aws_region`: `include.region.locals.aws_region` (From `region.hcl`)
- `tags`: `include.region.locals.tags` (From `region.hcl`)
- `eks_cluster_name`: `dependency.eks.outputs.cluster_name` (From `eks` module)
- `cluster_endpoint`: `dependency.eks.outputs.cluster_endpoint` (From `eks` module)
- `cluster_certificate_authority_data`: `dependency.eks.outputs.cluster_certificate_authority_data` (From `eks` module)
- `cluster_oidc_provider_arn`: `dependency.eks.outputs.oidc_provider_arn` (From `eks` module)
- `aws_account_id`: `dependency.eks.outputs.account_id` (From `eks` module)
- `cluster_oidc_issuer_url`: `replace(dependency.eks.outputs.oidc_provider_url, "https://", "")` (Processed from `eks` module output)
- `polaris_helm_chart_version`: `terragrunt/us-east-1/security-policies/terragrunt.hcl` (Value: `5.18.0`)
- `enabled`: (Default: `true`)
- `cluster_name`: (Duplicate of `eks_cluster_name`, from `dependency.eks.outputs.cluster_name`)
- `data_namespace`: (Default: `data`)
- `argocd_namespace`: (Default: `argocd`)

Outputs:
--------
- None defined in `outputs.tf`.

Versioning: 
-----------
- Polaris Helm Chart: `5.18.0`

Providers/Required providers:
------------------------------
- `hashicorp/kubernetes`: `~> 2.20` (Locked version: `2.36.0`)
- `hashicorp/helm`: `~> 2.10` (Locked version: `2.17.0`)
- `gavinbunney/kubectl`: `~> 1.14` (Locked version: `1.19.0`)
- `hashicorp/aws` (implicitly used by k8s provider auth)

</rewritten_file> 