# EKS Blizzard - Technical Documentation

## 1. Overview

This document provides detailed technical specifications for the EKS Blizzard project, a multi-region AWS EKS infrastructure designed for deploying and managing containerized applications using GitOps principles.

**Key Goals:** (Derived from `Project_Master_Definition.md`)
*   High Availability (Multi-Region, Multi-AZ)
*   Infrastructure as Code (Terraform, Terragrunt)
*   GitOps Continuous Delivery (Argo CD)
*   Automated Scaling (Karpenter, KEDA)
*   Robust Monitoring and Alerting (Prometheus, Grafana, Alertmanager)
*   Secure Secret Management (AWS Secrets Manager, ESO)
*   Workload Isolation (Dedicated Node Groups)
*   Security Best Practices (Network Policies, PSS, Scanning)

## 2. Infrastructure (Terraform/Terragrunt)

Managed via Terraform modules (`terraform/modules/*`) orchestrated by Terragrunt (`terragrunt/*`).

### 2.1. Core Components (per region)

*   **VPC (`terraform/modules/vpc`, `terragrunt/us-east-1/networking`)**:
    *   Based on `terraform-aws-modules/vpc/aws` module (~> v5.0).
    *   CIDR: Defined per region (`terragrunt/<region>/region.hcl`, e.g., `10.10.0.0/16` for us-east-1).
    *   Availability Zones: 3 AZs per region (`terragrunt/<region>/region.hcl`, e.g., `us-east-1a/b/c`).
    *   Subnets: 3 Public, 3 Private across AZs.
        *   Public Subnets tagged for `kubernetes.io/role/elb: 1`.
        *   Private Subnets tagged for `kubernetes.io/role/internal-elb: 1` and `karpenter.sh/discovery: <cluster-name>`.
    *   NAT Gateways: Enabled, one per AZ in public subnets (`one_nat_gateway_per_az = true`).
    *   Internet Gateway: Attached for public subnets.
    *   DNS Support: Enabled (`enable_dns_hostnames`, `enable_dns_support`).
    *   Cluster Security Group (`aws_security_group.eks_cluster_sg`): Created within VPC module, allows all egress and ingress from self. Used by EKS control plane and potentially nodes.
*   **EKS Cluster (`terraform/modules/eks-cluster`, `terragrunt/us-east-1/eks`)**:
    *   Cluster Name: Defined per region (`terragrunt/<region>/region.hcl`, e.g., `eks-blizzard-us-east-1`).
    *   Kubernetes Version: Specified per region (`terragrunt/<region>/region.hcl`, e.g., `1.29`).
    *   Networking: Uses private subnets from the VPC module. Attaches the cluster security group created by the VPC module.
    *   API Endpoint Access: Private (`endpoint_private_access = true`), Public (`endpoint_public_access = true` - review if this should be false as per `Project_Master_Definition.md`).
    *   IAM Role (`aws_iam_role.eks_cluster_role`): Assumes `eks.amazonaws.com`, policies `AmazonEKSClusterPolicy`, `AmazonEKSServicePolicy` attached.
    *   OIDC Provider (`aws_iam_openid_connect_provider.eks_oidc`): Enabled for IRSA.
    *   Logging: API, Audit, Authenticator, ControllerManager, Scheduler logs enabled to CloudWatch.
    *   Encryption: Uses KMS key (`aws_kms_key.eks_encryption_key`) for encrypting Kubernetes secrets at rest. KMS Key ID defined in `terragrunt/<region>/region.hcl`.
*   **Node Groups (`terraform/modules/node-groups`, `terragrunt/us-east-1/node-groups`)**:
    *   Four Managed Node Groups created per cluster, spanning private subnets.
    *   Uses EKS Optimized AMIs (default behavior of `aws_eks_node_group`).
    *   Instance Types/Scaling: Defined per group in `terragrunt/<region>/node-groups/terragrunt.hcl`.
        *   **Monitoring**: `t3.large`, 1-3 nodes. Taint: `monitoring=true:NoSchedule`. Label: `node-role=monitoring`.
        *   **Management**: `t3.medium`, 1-3 nodes. Taint: `management=true:NoSchedule`. Label: `node-role=management`.
        *   **Services**: `m5.large`, 2-5 nodes. No Taint. Label: `node-role=services`.
        *   **Data**: `r5.xlarge`, 3-5 nodes. Taint: `role=data:NoSchedule`. Label: `node-role=data`.
    *   IAM Roles:
        *   Common Role (`aws_iam_role.eks_node_role`): Used by Monitoring, Management, Services groups. Policies: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`, `CloudWatchAgentServerPolicy`.
        *   Data Role (`aws_iam_role.eks_data_node_role`): Used by Data group. Includes common policies + custom EBS access policy (`aws_iam_policy.ebs_access_policy`).
*   **EKS Addons (`terraform/modules/eks-addons`, `terragrunt/us-east-1/eks-addons`)**:
    *   Installs core EKS addons using `aws_eks_addon` resource.
    *   Versions: Uses latest compatible by default unless specified in `terragrunt.hcl`.
    *   Addons: `vpc-cni`, `coredns`, `kube-proxy`, `aws-ebs-csi-driver`.
    *   IRSA: Creates IAM Roles for `vpc-cni` (`aws-node` SA), `ebs-csi-driver` (`ebs-csi-controller-sa` SA), and `external-dns` (`external-dns` SA in `kube-system`).
    *   ExternalDNS: Deploys the Bitnami ExternalDNS Helm chart (`helm_release.external_dns`) if `create_route53_dns_manager_irsa` is true. Configured to use the IRSA role, filter by `domain_name`, and use cluster name as TXT owner ID. Runs on management nodes. Includes NetworkPolicy (`external-dns-netpol.yaml`).
*   **KMS Key (`deploy-us-east.md` Step 2)**:
    *   Created manually via AWS CLI before Terraform runs.
    *   Alias: `alias/eks-blizzard-<region>-key`.
    *   Used for EKS secret encryption. Key ID passed to `terragrunt/<region>/region.hcl`.
*   **S3 Backend & DynamoDB Lock Table (`deploy-us-east.md` Step 2)**:
    *   Created manually via AWS CLI before Terraform runs.
    *   Bucket Name: `eks-blizzard-terragrunt-state-<accountid>`. Versioned, encrypted.
    *   Table Name: `eks-blizzard-terragrunt-locks`.
    *   Configured in root `terragrunt/terragrunt.hcl`.

### 2.2. Supporting Services (Terraform/Terragrunt)

*   **AWS Load Balancer Controller (`terraform/modules/argocd`, `terragrunt/us-east-1/argocd`)**:
    *   Deployed via Helm chart (`aws.github.io/eks-charts/aws-load-balancer-controller`) as part of the Argo CD module (dependency).
    *   Version: Specified in `terragrunt.hcl` (e.g., `1.6.2`).
    *   IAM Role: Creates IRSA role (`aws_iam_role.load_balancer_controller`) with policy from `policies/aws-load-balancer-controller-policy.json`. Role assumed by `aws-load-balancer-controller` SA in `kube-system`.
    *   Runs on `management` nodes.
*   **External Secrets Operator (`terraform/modules/external-secrets`, `terragrunt/us-east-1/external-secrets`)**:
    *   Deploys ESO Helm chart (`charts.external-secrets.io/external-secrets`).
    *   Version: Specified in `terragrunt.hcl` (e.g., `0.9.9`).
    *   IAM Role: Creates IRSA role (`aws_iam_role.external_secrets`) allowing access to Secrets Manager (`secretsmanager:GetSecretValue`, etc.) and SSM Parameter Store, scoped by prefix (`eks-blizzard/*`). Role assumed by `external-secrets` SA in `external-secrets` namespace.
    *   Creates `ClusterSecretStore` named `aws-secretsmanager` referencing the IRSA role.
    *   **Creates Secrets**: Manages secrets in AWS Secrets Manager (MySQL App User, Weather API, Slack Webhook, Grafana Admin). See Section 7.
    *   Runs on `management` nodes.
*   **Argo CD (`terraform/modules/argocd`, `terragrunt/us-east-1/argocd`)**:
    *   Deploys Argo CD Helm chart (`argoproj.github.io/argo-helm/argo-cd`).
    *   Version: Specified in `terragrunt.hcl` (e.g., `5.51.4`).
    *   Namespace: `argocd`.
    *   Ingress: Enabled by default, hostname `argocd-<region>.<domain>`, uses ACM cert ARN from `region.hcl`. Relies on AWS LB Controller.
    *   Runs on `management` nodes.
    *   Defines `ApplicationSet` resources via `kubectl_manifest` based on inputs (`terraform/modules/argocd/templates/applicationset.yaml`). Currently defines one for `monitoring`.
*   **Karpenter (`terraform/modules/karpenter`, `terragrunt/us-east-1/karpenter`)**:
    *   Deploys Karpenter Helm chart (`oci://public.ecr.aws/karpenter/karpenter`).
    *   Version: Specified in `terragrunt.hcl` (e.g., `1.3.3`).
    *   Namespace: `karpenter`.
    *   IAM Role: Creates IRSA role (`aws_iam_role.karpenter_controller`) with permissions for EC2 actions (`RunInstances`, `TerminateInstances`, etc.) and `iam:PassRole` for the node role. Assumed by `karpenter-controller` SA in `karpenter` namespace.
    *   Creates default `NodePool` (`kubectl_manifest.karpenter_provisioner`, template `nodepool.yaml`) targeting private subnets, cluster security group, specific instance types (m5, c5, r5), OnDemand/Spot capacity, AL2 AMI. Labels nodes `node-role=services`. Uses node role from `node-groups` module output. Sets consolidation policy and TTL.
    *   Runs on `management` nodes.
*   **KEDA (`terraform/modules/keda`, `terragrunt/us-east-1/keda`)**:
    *   Deploys KEDA Helm chart (`kedacore.github.io/charts/keda`).
    *   Version: Specified in `terragrunt.hcl` (e.g., `2.16.0`).
    *   Namespace: `keda`.
    *   IAM Role: Creates minimal IRSA role (`aws_iam_role.keda_controller`) for potential future AWS scaler use (e.g., CloudWatch). Assumed by `keda-operator` SA in `keda` namespace.
    *   Creates `ScaledObject` (`kubectl_manifest.keda_scaled_object`, template `scaled-object.yaml`) targeting the `app` deployment in `default` namespace. Uses Prometheus trigger querying `http://prometheus-server.monitoring.svc.cluster.local:9090` for `http_requests_per_second`. Scales between 2 and 10 replicas.
    *   Runs on `management` nodes.
*   **Trivy Operator (`terraform/modules/trivy-operator`, `terragrunt/us-east-1/trivy-operator`)**:
    *   Deploys Trivy Operator Helm chart (`aquasecurity.github.io/helm-charts/trivy-operator`).
    *   Version: Specified in `terragrunt.hcl` (e.g., `0.27.0`).
    *   Namespace: `trivy-system`.
    *   IAM Role: Creates minimal IRSA role (`aws_iam_role.trivy_operator`) for potential future AWS integration (e.g., ECR scanning). Assumed by `trivy-operator` SA in `trivy-system` namespace.
    *   Configuration (`templates/values.yaml`): Enables vulnerability, config audit, RBAC, infra, secret scanners. Disables built-in Prometheus, enables `ServiceMonitor`. Ignores unfixed vulns, reports CRITICAL/HIGH. Scan jobs tolerate all taints (`operator: Exists`).
    *   Runs on `management` nodes.
*   **Network Policies (`terraform/modules/network-policies`, `terragrunt/us-east-1/network-policies`)**:
    *   Applies `NetworkPolicy` resources using `kubectl_manifest`.
    *   Default Deny: Applies `default-deny.yaml` template to `default`, `monitoring`, `keda`, `argocd`, `external-secrets`, `data`, `logging`, `trivy-system`, `security` namespaces.
    *   DNS Allow: Applies `allow-dns.yaml` to allow egress to `kube-dns` in `kube-system` from all managed namespaces.
    *   Specific Allows: Defines ingress/egress rules between components (e.g., `app-to-mysql.yaml`, `prometheus-to-targets.yaml`, `allow-ingress-to-app.yaml`, `allow-app-egress-internet.yaml`, `allow-karpenter-egress.yaml`, `fluentd-to-elasticsearch.yaml`, etc.). See templates for details.
*   **Security Policies (`terraform/modules/security-policies`, `terragrunt/us-east-1/security-policies`)**:
    *   Deploys Polaris Helm chart (`charts.fairwinds.com/stable/polaris`). Version `5.18.0`. Namespace `security`. Runs on `management` nodes. Dashboard enabled, webhook disabled. Configured with specific checks enabled/disabled (`templates/polaris-values.yaml`).
    *   Applies Pod Security Standards (PSS) labels (`restricted`) to namespaces via `templates/restricted-pss.yaml` (applied via `kubectl_manifest`). **Note:** The `main.tf` seems incomplete or was partially refactored, only Polaris Helm release is present. PSS application needs confirmation.
    *   Applies Kubernetes Audit Policy via ConfigMap (template `audit-policy.yaml`, applied via `kubectl_manifest`). **Note:** Audit policy application seems missing from `main.tf`.

### 2.3. Tooling Versions (as specified or defaulted)

*   Terraform: `~> 1.11` (Root `terragrunt.hcl`)
*   Terragrunt: v0.50+ (Implied by `deploy-us-east.md`)
*   AWS Provider: `~> 5.0` (Root `terragrunt.hcl`)
*   Kubernetes Provider: `~> 2.20` (Root `terragrunt.hcl`)
*   Helm Provider: `~> 2.10` (Root `terragrunt.hcl`)
*   Kubectl Provider: `~> 1.14` (Root `terragrunt.hcl`)
*   EKS Kubernetes Version: `1.29` (`terragrunt/us-east-1/region.hcl`)
*   Helm: v3+ (`deploy-us-east.md`)
*   Argo CD Helm Chart: `5.51.4` (`terragrunt/us-east-1/argocd/terragrunt.hcl`) -> Argo CD ~v2.10+
*   AWS LB Controller Chart: `1.6.2` (`terragrunt/us-east-1/argocd/terragrunt.hcl`)
*   External Secrets Chart: `0.9.9` (`terragrunt/us-east-1/external-secrets/terragrunt.hcl`)
*   Karpenter Chart: `1.3.3` (`terragrunt/us-east-1/karpenter/terragrunt.hcl`) -> Karpenter ~v1.3.3
*   KEDA Chart: `2.16.0` (`terragrunt/us-east-1/keda/terragrunt.hcl`) -> KEDA v2.16.0
*   Trivy Operator Chart: `0.27.0` (`terragrunt/us-east-1/trivy-operator/terragrunt.hcl`)
*   Kube Prometheus Stack Chart: `51.4.0` (`helm-chart/monitoring/Chart.yaml`)
*   MySQL (Bitnami) Chart: `9.10.5` (`helm-chart/mysql/Chart.yaml`) -> MySQL ~8.0.32
*   Elasticsearch Image: `8.10.4` (`helm-chart/elasticsearch/Chart.yaml`)
*   Fluentd (Bitnami) Chart: `5.8.7` (`helm-chart/fluentd/Chart.yaml`) -> Fluentd ~v1.16.1
*   ExternalDNS (Bitnami) Chart: `8.7.11` (`terraform/modules/eks-addons/variables.tf`)
*   Polaris Chart: `5.18.0` (`terraform/modules/security-policies/main.tf`)

## 3. Application Deployment (Argo CD / Helm)

*   **GitOps:** Argo CD manages deployments based on manifests in the Git repository.
*   **ApplicationSets:** Defined in `argocd/` directory, applied via `kubectl apply` (`deploy-us-east.md` Step 10).
    *   `crd-applicationset.yaml`: Deploys all CRDs from `crd-manifests/all-crds/` to `kube-system`.
    *   `stateful-applicationset.yaml`: Deploys MySQL, Elasticsearch, Fluentd using list generator. Targets `helm-chart/<appname>`.
    *   `app-applicationset.yaml`: Deploys the Python application using list generator. Targets `helm-chart/app`. Passes region-specific ECR repo and ingress host as parameters.
    *   `monitoring-applicationset.yaml`: Deploys the monitoring stack using list generator. Targets `helm-chart/monitoring`. Passes dynamic secret names (`slackWebhookSecretName`, `grafanaAdminSecretName`) obtained from Terragrunt outputs.
    *   `autoscaling-applicationset.yaml`: (Mentioned in `deploy-us-east.md` but file missing in context) Would likely deploy Karpenter `NodePool` and KEDA `ScaledObject` manifests if they were managed via GitOps instead of Terraform. Currently, these seem deployed by Terraform modules directly.
    *   `security-applicationset.yaml`: (Mentioned as skipped in `deploy-us-east.md`) Likely intended for security tools if not deployed via Terraform.

## 4. CI/CD Pipeline (GitHub Actions)

*   **Workflow:** `.github/workflows/ci-cd.yaml`
*   **Trigger:** Push to `main` branch on changes in `app/`, `helm-chart/`, or the workflow file itself.
*   **Steps:**
    1.  Checkout code (using PAT for commit access).
    2.  Configure AWS credentials (using GitHub Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `PAT`).
    3.  Log in to ECR (`us-east-1` and `us-west-2`).
    4.  Build Docker image from `app/Dockerfile` using Python 3.11-slim base.
    5.  Tag image with `github.sha` and `latest`.
    6.  Push image to ECR in both regions (`eks-blizzard/app` repository).
    7.  Update `helm-chart/app/values.yaml` -> `image.tag` with `github.sha`.
    8.  Update `helm-chart/app/Chart.yaml` -> `version` (using run number) and `appVersion` (using `github.sha`).
    9.  Commit and push `values.yaml` and `Chart.yaml` changes back to the `main` branch.

## 5. Python Application (`app/`)

*   **Framework:** Flask (`flask==2.3.3`).
*   **Dependencies (`requirements.txt`):** `flask`, `requests`, `mysql-connector-python`, `gunicorn`, `prometheus-client`.
*   **Dockerfile (`Dockerfile`):** Uses `python:3.11-slim`, installs deps, copies code, runs as non-root `appuser`, exposes port 5000, runs via `python app.py`.
*   **Functionality (`app.py`):**
    *   `/`: Main endpoint. Displays Client IP, Welcome Message, Container ID, Tel-Aviv Temp. Logs request to MySQL. Records Prometheus metrics.
    *   `/health`: Basic health check, returns `{"status": "healthy"}`.
    *   `/metrics`: Exposes Prometheus metrics (`http_requests_total`, `http_request_duration_seconds`, `temperature_fetch_errors_total`, `db_errors_total`).
*   **Configuration (Environment Variables):** `WELCOME_MESSAGE`, `WEATHER_API_KEY`, `WEATHER_API_URL`, `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `CONTAINER_ID` (via Downward API).
*   **Weather API:** Calls `WEATHER_API_URL` (OpenWeatherMap) using `WEATHER_API_KEY`. Handles errors and increments `temperature_fetch_errors_total`.
*   **MySQL Interaction:** Connects using DB credentials from env vars. Creates table `requests` if not exists. Inserts request timestamp, client IP, and container ID. Handles errors and increments `db_errors_total`.

## 6. Stateful Services (Helm Charts)

*   **MySQL (`helm-chart/mysql`)**:
    *   Uses Bitnami MySQL chart (`9.10.5`) as dependency.
    *   Deploys a standalone StatefulSet (`architecture: standalone`) in `data` namespace.
    *   Runs on `data` nodes (`nodeSelector`, `tolerations`).
    *   Persistence: Enabled, 20Gi `gp3` EBS volume via PVC.
    *   Auth: Root password managed internally. App user (`app_user`), DB (`app_db`) created by chart. App user password sourced from K8s secret `mysql-app-user-password-secret` (synced by ESO).
    *   Service: `ClusterIP` on port 3306.
    *   ESO Sync: Includes `ExternalSecret` (`mysql-app-password-eso-sync`) to sync *only* the app password from AWS SM into `mysql-app-user-password-secret`.
*   **Elasticsearch (`helm-chart/elasticsearch`)**:
    *   Custom chart using official `docker.elastic.co/elasticsearch/elasticsearch:8.10.4` image.
    *   Deploys a 3-replica StatefulSet in `data` namespace.
    *   Runs on `data` nodes (`nodeSelector`, `tolerations`).
    *   Topology Spread: Configured across zones (`topology.kubernetes.io/zone`).
    *   Persistence: Enabled, 30Gi `gp2` EBS volume per replica via PVC.
    *   Security: Disabled (`xpack.security.enabled: false`).
    *   Discovery: Configured for multi-node (`discovery.seed_hosts`, `cluster.initial_master_nodes`).
    *   Service: Headless (`elasticsearch-headless`) and ClusterIP (`elasticsearch`) on ports 9200 (http) and 9300 (transport).
    *   ILM Setup: Includes a post-install/upgrade Job (`elasticsearch-setup-ilm`) to create an Index Lifecycle Management policy (`logs-policy` - 7d hot rollover, 30d warm, 90d delete) and an index template (`logs-template`) for `k8s-logs-*` indices.
*   **Fluentd (`helm-chart/fluentd`)**:
    *   Uses Bitnami Fluentd chart (`5.8.7`) as dependency.
    *   Deploys as a DaemonSet in `logging` namespace.
    *   Runs on all nodes (`tolerations: - operator: "Exists"`).
    *   Configuration (`templates/configmap.yaml`, sourced from `values.yaml`):
        *   Tails container logs (`/var/log/containers/*.log`).
        *   Parses JSON logs.
        *   Adds Kubernetes metadata.
        *   Outputs to Elasticsearch (`elasticsearch.data.svc.cluster.local:9200`) using `logstash_format`. Index prefix `k8s-logs`.
        *   Includes basic health check endpoint.

## 7. Monitoring & Alerting (`helm-chart/monitoring`)

*   **Stack:** Uses `kube-prometheus-stack` Helm chart (`51.4.0`) as a dependency. Deployed to `monitoring` namespace. Runs on `monitoring` nodes.
*   **Prometheus:**
    *   StatefulSet, 1 replica.
    *   Persistence: Enabled, 50Gi `gp2` EBS volume.
    *   Configuration: Scrapes kube-state-metrics, node-exporter, MySQL exporter, Elasticsearch exporter, KEDA metrics API server. Uses `ServiceMonitor` and `PodMonitor` auto-discovery (`*SelectorNilUsesHelmValues: true`). Includes additional scrape configs for MySQL/ES exporters.
    *   Alerting Rules: Includes default rules from chart + custom rules (`templates/prometheus-rules.yaml`) for MySQL connections, ES cluster health/heap, App error rate/latency, Karpenter errors, Node CPU/Memory.
*   **Grafana:**
    *   Deployment, 1 replica.
    *   Persistence: Enabled, 10Gi `gp2` EBS volume.
    *   Auth: Admin credentials sourced from K8s secret `grafana-admin-credentials` (synced by ESO).
    *   Data Sources: Prometheus (default), Elasticsearch (`http://elasticsearch.data.svc.cluster.local:9200`).
    *   Dashboards: Default chart dashboards disabled. Custom placeholder dashboards (`templates/grafana-dashboards.yaml`) provisioned via ConfigMaps and sidecar.
    *   Ingress: Defined in `templates/grafana-ingress.yaml`. Uses ALB, ACM cert (passed as value), hostname `grafana-<region>.<domain>`. Relies on AWS LB Controller and ExternalDNS. **Note:** ACM Cert ARN needs to be passed correctly via Argo CD ApplicationSet parameter.
*   **Alertmanager:**
    *   StatefulSet, 1 replica.
    *   Persistence: Enabled, 10Gi `gp2` EBS volume.
    *   Configuration: Defined via `AlertmanagerConfig` CRD (`templates/alertmanager-config.yaml`). Configures a default route to `slack-receiver`.
    *   Slack Integration: `slack-receiver` uses webhook URL from K8s secret `alertmanager-slack-webhook` (synced by ESO). Sends notifications to `#alerts` channel.
*   **Exporters:**
    *   `prometheus-mysql-exporter`: Deployed via sub-chart. Connects to `mysql.data:3306`. Password is **placeholder** and needs secure injection (See Section 7 Task 2). Runs on `monitoring` nodes. `ServiceMonitor` enabled.
    *   `prometheus-elasticsearch-exporter`: Deployed via sub-chart. Connects to `http://elasticsearch.data.svc.cluster.local:9200`. Runs on `monitoring` nodes. `ServiceMonitor` enabled.
*   **ESO Sync:** Includes `ExternalSecret` resources (`externalsecret-slack.yaml`, `externalsecret-grafana.yaml`) to sync Slack webhook and Grafana credentials from AWS SM into K8s secrets.

## 8. Autoscaling

*   **Pod Scaling (KEDA):** See Section 2.2. Scales `app` deployment based on Prometheus query `sum(rate(http_requests_total{app="app"}[5m])) > 10`. Min 2, Max 10 replicas.
*   **Node Scaling (Karpenter):** See Section 2.2. Provisions new nodes based on pending pods, primarily for the `services` workload. Uses `NodePool` definition, mixes OnDemand/Spot, specific instance types (m5, c5, r5), AL2 AMI. Consolidation enabled.

## 9. Security

*   **Secret Management:** AWS Secrets Manager + ESO + IRSA. See Section 7.
*   **Network Policies:** Default deny applied. Specific allow rules for necessary traffic between components (App<->DB, Prometheus<->Exporters, Ingress<->App, etc.). See `terraform/modules/network-policies/templates/`.
*   **Pod Security Standards (PSS):** Intended to apply `restricted` profile labels to namespaces (defined in `terraform/modules/security-policies/templates/restricted-pss.yaml`, but application via Terraform needs verification).
*   **Vulnerability Scanning:** Trivy Operator deployed via Terraform. Scans images and configurations. ECR scan-on-push enabled.
*   **Configuration Auditing:** Polaris deployed via Terraform. Audits K8s resources against best practices.
*   **IAM:** Least privilege roles for EKS Cluster, Nodes, and Controllers (via IRSA). See individual Terraform modules.
*   **API Access:** EKS API endpoint configured for private access (needs verification of public access setting). `deploy-us-east.md` implies use of `aws eks update-kubeconfig`.
*   **Audit Logging:** EKS control plane logs sent to CloudWatch. Audit policy intended to be applied via `terraform/modules/security-policies` (needs verification).

## 10. Placeholders and Configuration Points

*   **`TF_VAR_weather_api_key`**: Must be set when applying `external-secrets` Terragrunt module.
*   **`TF_VAR_slack_webhook_url`**: Must be set when applying `external-secrets` Terragrunt module (or replace placeholder in `terragrunt.hcl`).
*   **MySQL Exporter Password**: Placeholder in `helm-chart/monitoring/values.yaml` needs replacement with secure injection method.
*   **Argo CD Initial Admin Password**: Temporary, needs changing post-deployment.
*   **ACM Certificate ARN**: Hardcoded in `terragrunt/<region>/region.hcl` and `argocd/app-applicationset.yaml`. Should ideally be a variable or data source lookup.
*   **ECR Repository URL**: Constructed using Account ID and Region in `helm-chart/app/values.yaml` (via Argo CD parameter) and `.github/workflows/ci-cd.yaml`. Account ID needs to be correctly available.
*   **Git Repo URL**: Hardcoded in ApplicationSet definitions (`argocd/*.yaml`). Should use a variable or be configured via Argo CD settings if repo changes.
*   **GitHub PAT**: Required as secret (`PAT`) for CI/CD workflow to push Helm chart updates back to the repo.

## 11. Testing (`testing/`)

*   **Load Test (`load-test.yaml`):** Kubernetes Job using `loadimpact/k6` to generate load against `https://app.blizzard.co.il/`. Used to test KEDA/Karpenter autoscaling.
*   **Security Tests (`security-tests.sh`):** Script to perform basic checks:
    *   Network policy validation (attempts `wget` to MySQL/ES).
    *   PSS validation (attempts to create privileged/hostNetwork pods).
    *   Secret existence checks (`kubectl get externalsecret`, `secret`).
    *   Vulnerability report check (`kubectl get vulns`).
    *   Audit policy check (`kubectl get configmap -n kube-system audit-policy`).
    *   Polaris config check (`kubectl get cm -n security polaris-config`).
    *   Local Trivy image scan.

This document provides a snapshot of the technical details based on the provided project files. Further refinement and verification, especially regarding placeholder values and policy application, is recommended. 