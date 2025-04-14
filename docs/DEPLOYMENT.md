# EKS Production Project Deployment Guide (Part 1)

## Introduction

### Project Goal
This project aims to deploy a resilient, scalable, and observable Python web application on Amazon EKS (Elastic Kubernetes Service) across multiple AWS regions (`us-east-1` and `us-west-2`). It leverages Infrastructure as Code (IaC) principles using Terraform and Terragrunt for managing AWS resources and employs GitOps practices via Argo CD for Kubernetes application deployments. The setup includes comprehensive monitoring, logging, security scanning, and autoscaling capabilities within each region.

### Architecture Overview
The core infrastructure consists of independent EKS clusters in each target region, each spanning multiple Availability Zones (AZs). Within each region, a VPC with public and private subnets provides network isolation. Managed Node Groups are used for specific workloads (monitoring, management, data, services), and Karpenter is employed for dynamic, efficient node autoscaling based on workload demand in each cluster.

Applications and services are deployed via Helm charts managed by Argo CD ApplicationSets. The setup within each regional cluster includes:
*   A sample Python web application (`app`).
*   A MySQL database (`mysql`) for the application, running in the `data` namespace.
*   An Elasticsearch cluster (`elasticsearch`) for log aggregation, running in the `data` namespace.
*   Fluentd (`fluentd`) as a DaemonSet for log shipping from nodes to Elasticsearch, running in the `logging` namespace.
*   A monitoring stack (`kube-prometheus-stack`) including Prometheus, Grafana, and Alertmanager, running in the `monitoring` namespace.
*   Security tools including Trivy Operator (vulnerability/compliance scanning) and Polaris (configuration best practices), running in their respective namespaces (`trivy-system`, `security`).
*   KEDA for event-driven application autoscaling based on Prometheus metrics.
*   External Secrets Operator (ESO) for securely managing secrets (like API keys and database credentials) stored in AWS Secrets Manager and syncing them to Kubernetes Secrets.
*   AWS Load Balancer Controller for managing AWS Application Load Balancers (ALBs) via Kubernetes Ingress resources.
*   ExternalDNS for automatically managing Route 53 DNS records based on Ingress resources.

### Core Technologies
*   **AWS:** EKS, VPC, EC2, ALB, Route 53, S3 (for Terraform state), Secrets Manager, KMS, IAM, ECR.
*   **IaC:** Terraform, Terragrunt.
*   **Kubernetes:** EKS, Helm, kubectl.
*   **GitOps:** Argo CD.
*   **CI/CD:** GitHub Actions (for building/pushing images and updating Helm charts).
*   **Containerization:** Docker.
*   **Monitoring:** Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics.
*   **Logging:** Elasticsearch, Fluentd.
*   **Security:** Trivy Operator, Polaris, Network Policies, AWS IAM/IRSA.
*   **Autoscaling:** Karpenter (Nodes), KEDA (Application).
*   **Secrets Management:** External Secrets Operator (ESO), AWS Secrets Manager.
*   **Networking:** AWS Load Balancer Controller, ExternalDNS, Kubernetes Network Policies.
*   **Application:** Python (Flask), Docker.

### Deployed Components Summary (Per Region)
*   **Infrastructure (Terraform/Terragrunt):** VPC, Subnets, NAT Gateways, IGW, Security Groups, EKS Cluster, IAM Roles/Policies, KMS Key, EKS Managed Node Groups, EKS Addons (VPC CNI, CoreDNS, Kube Proxy, EBS CSI Driver), Route 53 IAM resources, Kubernetes Namespaces.
*   **Cluster Services (Argo CD/Helm):** Argo CD, AWS Load Balancer Controller, External Secrets Operator, Karpenter, KEDA, Trivy Operator, Polaris, MySQL Exporter, Elasticsearch Exporter, Fluentd.
*   **Monitoring Stack (Argo CD/Helm):** Prometheus, Grafana, Alertmanager.
*   **Application Workloads (Argo CD/Helm):** `app` (Python Web App), `mysql`, `elasticsearch`.

## IMPORTANT: Cost Warning 💸

Deploying this project involves provisioning numerous AWS resources **in each target region** (`us-east-1` and `us-west-2`), many of which incur costs based on usage and uptime. Based on the configured minimum node counts, EKS control plane costs, multiple NAT gateways, load balancers, and storage per region, a **rough estimate** for running this full multi-region infrastructure is:

*   **Daily Cost:** Approximately **$70 - $100+ USD** (Roughly $35-$50+ per region)
*   **Monthly Cost:** Approximately **$2100 - $3000+ USD** (Roughly $1050-$1500+ per region)

**Disclaimer:** This is only an estimate. Actual costs can vary significantly based on:
*   Actual node usage and scaling triggered by Karpenter/KEDA in *each region*.
*   Data transfer fees (NAT Gateway, inter-AZ, internet egress) *per region*.
*   Load Balancer traffic (LCU costs) *per region*.
*   API requests to AWS Secrets Manager and other services.
*   Specific instance types chosen by Karpenter (Spot vs On-Demand).
*   Differences in AWS regional pricing.

**It is strongly recommended to use the AWS Pricing Calculator (https://calculator.aws/) to get a more accurate estimate based on your expected usage patterns and regional pricing before deployment.** Remember to **destroy** the infrastructure in *both regions* when not actively using it to avoid ongoing charges.

## Technical Documentation

Detailed technical documentation for the individual infrastructure and application modules can be found in:

*   **Terraform/Terragrunt Modules:** `docs/terraform.md`
*   **Argo CD ApplicationSets & Helm Charts:** `docs/argocd_modules.md`

Refer to these documents for specifics on inputs, outputs, deployed components, hardcoded values, and versioning for each module.

## Deployment Steps

### Prerequisites

This section covers the necessary tools and configurations required before deploying the infrastructure.

#### 1. Local Tools Installation

Ensure the following tools are installed on your local machine:

```bash
# Install AWS CLI version 2
# (Instructions: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

# Install kubectl (v1.29 or compatible with your cluster version)
# (Instructions: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

# Install Terraform (v1.11+)
# (Instructions: https://developer.hashicorp.com/terraform/downloads)

# Install Terragrunt (v0.50+)
# (Instructions: https://terragrunt.gruntwork.io/docs/getting-started/install/)

# Install Helm (v3+)
# (Instructions: https://helm.sh/docs/intro/install/)

# Install jq (for JSON processing)
sudo apt-get update && sudo apt-get install -y jq # Debian/Ubuntu
# brew install jq # macOS

# Install Docker (for building images)
# (Instructions: https://docs.docker.com/engine/install/)

# Verify installations
aws --version
kubectl version --client
terraform version
terragrunt version
helm version
docker --version
jq --version
```

_(Note: `jq` is used for parsing JSON, particularly useful when scripting interactions with AWS CLI or `kubectl`.)_

#### 2. Configure AWS CLI

Configure your default AWS CLI profile to point to `us-east-1` (or your primary region). Ensure the credentials have permissions to create resources in **both `us-east-1` and `us-west-2`** (or your target regions).

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region name: us-east-1
# Default output format: json
```

# Verify credentials
aws sts get-caller-identity

#### 3. GitHub Repository Setup & Code Preparation

This project uses GitHub Actions for CI/CD (building container images) and Argo CD for GitOps (deploying applications). You'll need your own repository.

1.  **Fork or Clone:**
    *   **Option A (Fork):** Fork the original repository (`https://github.com/AmichaiHadad/eks_production_project.git`) into your own GitHub account. This preserves the history.
    *   **Option B (New Repo):**
        *   Clone the original repository locally:
            ```bash
            git clone https://github.com/AmichaiHadad/eks_production_project.git my-eks-project # Replace with the correct repo URL if different
            cd my-eks-project
            ```
        *   Remove the original remote: `git remote remove origin`
        *   Create a new repository on GitHub (e.g., `my-eks-production-project`).
        *   Add your new repository as the remote:
            ```bash
            git remote add origin git@github.com:<your-username>/my-eks-production-project.git # Use SSH URL
            # Or: git remote add origin https://github.com/<your-username>/my-eks-production-project.git # Use HTTPS URL
            ```
        *   Push the code to your new repository: `git push -u origin main` (or your default branch).

2.  **Update Repository URLs:**
    *   Search through the codebase (especially `terragrunt/**/terragrunt.hcl` files and `argocd/*.yaml` files) and replace any hardcoded references to the original repository (`https://github.com/AmichaiHadad/...`) with the URL of **your** new repository.

#### 4. GitHub Actions Secrets

The CI/CD workflow (`.github/workflows/ci-cd.yaml`) requires AWS credentials to push container images to ECR in both regions.

1.  **Create AWS IAM User:** Create a dedicated IAM user for GitHub Actions with programmatic access (Access Key ID and Secret Access Key).
2.  **Grant Permissions:** Attach a policy to this IAM user granting permissions to:
    *   Authenticate to ECR (`ecr:GetAuthorizationToken`).
    *   Push images to the specific ECR repositories (`ecr:BatchCheckLayerAvailability`, `ecr:CompleteLayerUpload`, `ecr:InitiateLayerUpload`, `ecr:PutImage`, `ecr:UploadLayerPart`). Scope this down to the specific repository ARNs you create in the next step (e.g., `arn:aws:ecr:us-east-1:<YOUR_ACCOUNT_ID>:repository/eks-blizzard/app` and the `us-west-2` equivalent).
3.  **Configure GitHub Secrets:** In your **GitHub repository**, go to `Settings` > `Secrets and variables` > `Actions`. Create the following repository secrets:
    *   `AWS_ACCESS_KEY_ID`: Your IAM user's Access Key ID.
    *   `AWS_SECRET_ACCESS_KEY`: Your IAM user's Secret Access Key.

#### 5. AWS Prerequisites Setup

Create these resources **before** running `terragrunt apply`.

1.  **S3 Bucket & DynamoDB Table (Terraform Backend):**
    *   Choose a region (e.g., `us-east-1`) for your backend.
    *   Create an S3 bucket (e.g., `your-unique-prefix-tfstate`). Enable versioning and encryption.
    *   Create a DynamoDB table (e.g., `your-unique-prefix-tflocks`) with a primary key named `LockID` (Type: String). Enable encryption.

```bash
TF_STATE_BUCKET="eks-blizzard-terragrunt-state-$(aws sts get-caller-identity --query Account --output text)"
TF_LOCK_TABLE="eks-blizzard-terragrunt-locks"
AWS_REGION="us-east-1"

# Create S3 bucket (ensure unique name)
aws s3api create-bucket --bucket ${TF_STATE_BUCKET} --region ${AWS_REGION}

# Enable versioning
aws s3api put-bucket-versioning --bucket ${TF_STATE_BUCKET} --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption --bucket ${TF_STATE_BUCKET} --server-side-encryption-configuration '{\"Rules\": [{\"ApplyServerSideEncryptionByDefault\": {\"SSEAlgorithm\": \"AES256\"}}]}}'

# Create DynamoDB table
aws dynamodb create-table \
  --table-name ${TF_LOCK_TABLE} \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${AWS_REGION}

# Verify creation (optional)
echo "State Bucket: ${TF_STATE_BUCKET}"
echo "Lock Table: ${TF_LOCK_TABLE}"
```
    *   **Update `terragrunt/terragrunt.hcl`:** Modify the `remote_state.config` block with your bucket name, chosen region, and DynamoDB table name (see Step 6 below).

2.  **KMS Keys (One per Region):**
    *   This key encrypts Kubernetes secrets within the EKS control plane for each region.

```bash
# Create KMS key for us-east-1
KMS_KEY_ID_EAST=$(aws kms create-key --description "EKS Secret Encryption Key us-east-1" --region us-east-1 --query KeyMetadata.KeyId --output text)
aws kms create-alias --alias-name "alias/eks-blizzard-us-east-1-key" --target-key-id ${KMS_KEY_ID_EAST} --region us-east-1
echo "KMS Key for us-east-1: ${KMS_KEY_ID_EAST}"

# Create KMS key for us-west-2
KMS_KEY_ID_WEST=$(aws kms create-key --description "EKS Secret Encryption Key us-west-2" --region us-west-2 --query KeyMetadata.KeyId --output text)
aws kms create-alias --alias-name "alias/eks-blizzard-us-west-2-key" --target-key-id ${KMS_KEY_ID_WEST} --region us-west-2
echo "KMS Key for us-west-2: ${KMS_KEY_ID_WEST}"
```
    *   Note down both `KMS_KEY_ID_EAST` and `KMS_KEY_ID_WEST` for configuration in Step 6.

3.  **ECR Repositories (One per Region):**
    *   This repository will store your application's Docker image in each region. The GitHub Action expects the name `eks-blizzard/app`.

```bash
AWS_REGION="us-east-1"
ECR_REPO_NAME="eks-blizzard/app"

# Create repository
aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION}
aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region us-west-2

# Enable image scanning
aws ecr put-image-scanning-configuration --repository-name ${ECR_REPO_NAME} --image-scanning-configuration scanOnPush=true --region ${AWS_REGION}
aws ecr put-image-scanning-configuration --repository-name ${ECR_REPO_NAME} --image-scanning-configuration scanOnPush=true --region us-west-2

# Get ECR repository URL
ECR_REPO_EAST=$(aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${AWS_REGION} --query 'repositories[0].repositoryUri' --output text)
ECR_REPO_WEST=$(aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region us-west-2 --query 'repositories[0].repositoryUri' --output text)
echo "ECR Repository us-east-1: ${ECR_REPO_EAST}"
echo "ECR Repository us-west-2: ${ECR_REPO_WEST}"
```
    *   **(Optional) Image Scanning:** The commands enable scan-on-push. Review findings in the ECR console for each region.

4.  **ACM Certificates (One per Region):**
    *   **Requirement:** The project uses an AWS Load Balancer Controller Ingress for Argo CD and the application, requiring a TLS certificate managed by AWS Certificate Manager (ACM) in **each region**.
    *   **Action:** Request or import a public certificate for your domain (e.g., `*.your-domain.com` or specific subdomains like `app-us-east-1.your-domain.com`, `argocd-us-east-1.your-domain.com`) in **both** `us-east-1` and `us-west-2` via the ACM console. Ensure DNS validation is complete for both certificates.
    *   Note down the ARN for the certificate in `us-east-1` and the ARN for the certificate in `us-west-2`. You will need these in Step 6.

#### 6. Configure Terragrunt Files

1.  **Update Root `terragrunt/terragrunt.hcl`:**
    *   Update the `remote_state.config` block with the S3 bucket name, backend region (`us-east-1` or your chosen central region), and DynamoDB table name created in Step 5.1.
    *   Update the `inputs.aws_account_id` with your actual 12-digit AWS Account ID.

```hcl
# terragrunt/terragrunt.hcl
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "your-unique-prefix-tfstate" # <-- Update this
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1" # Set appropriately
    encrypt        = true
    dynamodb_table = "your-unique-prefix-tflocks" # <-- Update this
  }
}

# ... rest of the file ...
```

2.  **Update `terragrunt/us-east-1/region.hcl`:**
    *   Update `locals.kms_key_id` with the Key ID obtained for `us-east-1` in Step 5.2.
    *   Update `locals.acm_certificate_arn` with the ACM Certificate ARN for `us-east-1` obtained in Step 5.4.

```hcl
# terragrunt/us-east-1/region.hcl
locals {
  # ... other variables ...
  
  # EKS Configuration
  # ...
  kms_key_id = "YOUR_KMS_KEY_ID_EAST" # <-- Update this (e.g., from output of Step 5.2)
  
  # ... other variables ...
  
  # TLS certificate for HTTPS (Ensure this is correct for us-east-1)
  acm_certificate_arn = "YOUR_US_EAST_1_ACM_CERT_ARN" # <-- Update this (from Step 5.4)
}
```

3.  **Update `terragrunt/us-west-2/region.hcl`:**
    *   Update `locals.kms_key_id` with the Key ID obtained for `us-west-2` in Step 5.2.
    *   Update `locals.acm_certificate_arn` with the ACM Certificate ARN for `us-west-2` obtained in Step 5.4.

```hcl
# terragrunt/us-west-2/region.hcl
locals {
  # ... other variables ...
  
  # EKS cluster configuration
  # ...
  kms_key_id = "YOUR_KMS_KEY_ID_WEST" # <-- Update this (e.g., from output of Step 5.2)
  
  # ... other variables ...

  # TLS certificate for HTTPS
  acm_certificate_arn = "YOUR_US_WEST_2_ACM_CERT_ARN" # <-- Update this (from Step 5.4)
}
```

#### 7. Application Secrets Configuration (Pre-Deployment)

Secrets like the Slack webhook URL and Weather API key need to be configured **before** running Terragrunt apply, as the `external-secrets` module expects them.

1.  **Method: Environment Variables**
    *   Before running `terragrunt run-all apply` or `terragrunt apply-all`, set the following environment variables in your terminal:
        ```bash
        export TF_VAR_slack_webhook_url="YOUR_SLACK_WEBHOOK_URL"
        export TF_VAR_weather_api_key="YOUR_WEATHER_API_KEY"
        ```
    *   Terragrunt will automatically pick these up and pass them to the Terraform module.
    *   **Important:** Ensure these are set correctly for **each region's apply command** if deploying region-by-region, or in the shell where you run `run-all`.

2.  **Other Secrets:** Passwords for MySQL (root, app user) and Grafana admin are **generated randomly** within the `external-secrets` module deployed in *each region* and stored in AWS Secrets Manager *within that region*. You do not need to provide these beforehand.

## Step 4: Deploy Infrastructure with Terragrunt

Terragrunt manages the deployment order based on the `dependency` blocks within each region's `terragrunt.hcl` files.

1.  **Navigate & Initialize:**
    ```bash
    cd terragrunt
    ```
2.  **Initialize Terragrunt (fetches modules, sets up backend):**
    ```bash
    # This needs to be run once from the root
    terragrunt run-all init
    ```
3.  **(Optional) Plan Deployment:** To see what resources will be created/modified across *all* configured regions (`us-east-1` and `us-west-2`):
    ```bash
    # Set environment variables if using Method 2 for secrets
    export TF_VAR_slack_webhook_url="..."
    export TF_VAR_weather_api_key="..."

    terragrunt run-all plan
    ```
4.  **Deploy All Infrastructure (Both Regions):**
    ```bash # This is the recommended deployment method
    # Set environment variables if using Method 2 for secrets
    export TF_VAR_slack_webhook_url="..."
    export TF_VAR_weather_api_key="..."

    # Apply all configurations in both regions in the correct order
    terragrunt run-all apply
    ```
    *   Confirm the plan for each module in each region by typing `yes` when prompted.
    *   This command deploys the infrastructure stacks for `us-east-1` and `us-west-2` concurrently (respecting dependencies *within* each region). Ensure your **AWS credentials have permissions in both regions** and the **secrets environment variables** are set. The entire process will take a considerable amount of time (potentially 30-60 minutes or more).

5.  **(Alternative) Deploy Region by Region:**
    ```bash # Use if you need to deploy/debug one region at a time
    # Set environment variables if needed
    export TF_VAR_slack_webhook_url="..."
    export TF_VAR_weather_api_key="..."

    # Deploy us-east-1
    cd us-east-1
    terragrunt apply-all # Apply all modules within us-east-1 in order
    cd ..

    # Deploy us-west-2
    cd us-west-2
    terragrunt apply-all # Apply all modules within us-west-2 in order
    cd ..
    ```

## Step 5: Verify Deployment and Access Services

After successful `apply` commands for both regions, you should see outputs from various modules for *each region*, including:
*   EKS cluster endpoints (one for each region).
*   OIDC provider URLs/ARNs (one for each region).
*   Argo CD Ingress hostnames (potentially one per region if configured, though the example Argo CD module seems to assume a single Argo CD managing both clusters).
*   Generated secret names in AWS Secrets Manager (these will likely be region-specific due to the random suffixes unless pre-created globally). 

# EKS Production Project Deployment Guide (Part 2)

This part covers post-deployment steps like Argo CD synchronization, validation, accessing services, testing, CI/CD, and cleanup.

### Argo CD Synchronization

1.  **Creation:** The `argocd` Terragrunt module (deployed in each region during the `terragrunt apply` step) deploys Argo CD itself and creates the `ApplicationSet` resources defined in its regional `terragrunt.hcl`.
2.  **Automatic Sync:** The ApplicationSets (`app`, `monitoring`, `mysql`, `elasticsearch`, `fluentd`) are configured with `syncPolicy.automated`, meaning Argo CD in each region should automatically detect the ApplicationSet resources and create the corresponding regional `Application` resources (e.g., `app-us-east-1`, `monitoring-us-west-2`). These Applications will then sync automatically (`selfHeal: true`), pulling the Helm charts from the specified Git repository (`https://github.com/<your-username>/<your-repo-name>.git`) and deploying them to the respective regional cluster.
3.  **Checking Status (Per Region):**
    *   You need to check the Argo CD instance deployed in *each region* separately.
    *   **Update Kubeconfig:** Switch your `kubectl` context to the target region first:
        ```bash
        # For us-east-1
        aws eks update-kubeconfig --region us-east-1 --name eks-blizzard-us-east-1
        # or for us-west-2
        # aws eks update-kubeconfig --region us-west-2 --name eks-blizzard-us-west-2
        ```
    *   **UI:** Access the regional Argo CD UI (see "Accessing Services" below) and check the status of the applications for that region. They should eventually show `Synced` and `Healthy`. Initial syncs might take a few minutes.
    *   **CLI:** If you install the Argo CD CLI:
        ```bash
        # Login to the regional Argo CD
        argocd login <REGIONAL_ARGOCD_SERVER_URL> --username admin --password <REGIONAL_INITIAL_ADMIN_PASSWORD> --insecure
        # List apps for that region (e.g., app-us-east-1, monitoring-us-east-1, etc.)
        argocd app list
        # Get specific app status
        argocd app get <APP_NAME> # e.g., argocd app get app-us-east-1
        ```

#### Manual Application Synchronization (Optional)

If you need to deploy the ApplicationSets manually (e.g., if automated sync is disabled or for troubleshooting), you can apply their YAML definitions directly using `kubectl`. This will create the `ApplicationSet` resources within the Argo CD namespace, and the Argo CD ApplicationSet controller will then act upon them to create the `Application` resources.

**Prerequisites:**
*   Ensure `kubectl` is configured to point to the correct regional EKS cluster (using `aws eks update-kubeconfig --region <region> --name eks-blizzard-<region>`).

**Manual Apply Order (run from the project root directory):**

1.  **(CRDs First!)** Apply the CRD ApplicationSet to ensure Custom Resource Definitions are present before applications that use them:
    ```bash
    kubectl apply -n argocd -f argocd/crd-applicationset.yaml
    ```
2.  **MySQL:**
    ```bash
    kubectl apply -n argocd -f argocd/mysql-applicationset.yaml
    ```
3.  **Elasticsearch:**
    ```bash
    kubectl apply -n argocd -f argocd/elasticsearch-applicationset.yaml
    ```
4.  **Fluentd:**
    ```bash
    kubectl apply -n argocd -f argocd/fluentd-applicationset.yaml
    ```
5.  **Monitoring:**
    ```bash
    kubectl apply -n argocd -f argocd/monitoring-applicationset.yaml
    ```
6.  **App:**
    ```bash
    kubectl apply -n argocd -f argocd/app-applicationset.yaml
    ```

After applying each `ApplicationSet`, monitor the Argo CD UI or use `kubectl get applications -n argocd` and `argocd app get <app-name>` to check the synchronization status. Ensure dependent applications (like MySQL before the App) are healthy before proceeding.

## Validation and Testing (Per Region)

Thorough validation is crucial after deployment **in each region**. Repeat these steps for both `us-east-1` and `us-west-2` by ensuring your `kubectl` context is set to the correct cluster.

### Initial Checks

1.  **Terragrunt Outputs:** Review the outputs from the `terragrunt apply` command for the specific region.
2.  **Kubectl Context:** Set your context to the region you are validating:
    ```bash
    aws eks update-kubeconfig --region <region> --name eks-blizzard-<region>
    kubectl config current-context # Verify context
    ```
3.  **Nodes:** Check node status:
    ```bash
    kubectl get nodes -L node-role,karpenter.sh/capacity-type,topology.kubernetes.io/zone
    ```
    *   Verify nodes from managed groups and potentially Karpenter are `Ready` and correctly labeled/tainted.
4.  **Pods:** Check pod status across namespaces:
    ```bash
    kubectl get pods -A
    ```
    *   Verify pods in relevant namespaces (`kube-system`, `argocd`, `external-secrets`, etc.) are `Running`. Investigate any `Error` or `CrashLoopBackOff` statuses.

### Component Validation (Per Region)

*   **EKS Cluster:** AWS EKS Console for the region. `kubectl cluster-info`.
*   **Networking:** AWS VPC Console for the region. Check subnets, route tables, NAT GWs, IGW.
*   **ECR Repositories:** Verify `eks-blizzard/app` exists in both regional ECR consoles and contains the expected image tags after a CI/CD run.
*   **Node Groups / Karpenter:** (Same commands as before, run against the regional cluster context)
    *   `kubectl get nodes --show-labels`
    *   `kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -c controller`
    *   `kubectl get nodepool,ec2nodeclass`
    *   Perform the **Scaling Test** (deploying `high-resource-pod.yaml`) against the regional cluster to verify Karpenter provisions nodes correctly within that region's configured subnets/AZs.
*   **Argo CD:** Access the regional Argo CD UI. Verify regional applications are `Synced` and `Healthy`.
*   **External Secrets Operator:**
    *   `kubectl get pods -n external-secrets`
    *   `kubectl get externalsecret -n app`
    *   `kubectl get secret -n app app-secrets mysql-app-credentials -o yaml` (Verify secrets exist and data is populated)
    *   Repeat secret checks for `data` and `monitoring` namespaces.
*   **Monitoring Stack:**
    *   Access the regional Grafana UI. Check login with generated/retrieved admin password.
    *   Check Prometheus targets page (`/targets`) for the region's Prometheus. Verify exporters (node, kube-state-metrics, mysql, elasticsearch) are being scraped.
    *   Verify regional dashboards (Kubernetes, MySQL, Elasticsearch) load data.
    *   Check Alertmanager status (`/status`) and rules (`/alerts`) for the region. Test Slack integration if configured.
*   **Logging Stack:**
    *   `kubectl get pods -n logging` (Fluentd)
    *   `kubectl get pods -n data` (Elasticsearch)
    *   `kubectl exec -n data elasticsearch-0 -- curl localhost:9200/_cluster/health?pretty` (Check regional ES cluster health).
    *   Query regional `k8s-logs-*` indices in Grafana/Kibana.
*   **Security Tools:**
    *   `kubectl get pods -n trivy-system`
    *   `kubectl get vulnerabilityreports,configauditreports,clusterrbacassessmentreports,exposedsecretreports -A` (Check for reports)
    *   `kubectl get pods -n security` (Polaris)
    *   Port-forward to regional Polaris dashboard: `kubectl port-forward -n security svc/polaris-dashboard 8080:80`.
*   **Application (`app`):**
    *   Access the regional application Ingress URL.
    *   Verify functionality (welcome message, weather, DB logging).
    *   Check regional application logs: `kubectl logs -n app -l app.kubernetes.io/name=app`.
*   **KEDA:**
    *   Perform the KEDA load test against the regional application Ingress.
    *   Monitor regional HPA (`kubectl get hpa -n app app-scaler -w`).
    *   Check regional KEDA operator logs.
*   **Network Policies:** Perform connectivity tests using `kubectl exec` within the regional cluster context.

## Accessing Services (Per Region)

You will need to get the specific URLs and credentials for each regional deployment. The hostnames depend on the region and your configured domain (`blizzard.co.il` in the example).

1.  **Set `kubectl` context:**
    ```bash
    aws eks update-kubeconfig --region <region> --name eks-blizzard-<region>
    ```

2.  **Argo CD UI:**
    *   Get Hostname: `kubectl get ingress -n argocd argocd-server -o jsonpath='{.spec.rules[0].host}'`
    *   Get Password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo`
    *   Access `https://<argo-cd-hostname>`, login as `admin`.

3.  **Grafana UI:**
    *   Get Hostname: `kubectl get ingress -n monitoring monitoring-grafana -o jsonpath='{.spec.rules[0].host}'` (Check actual ingress name, might differ based on Argo CD release name).
    *   Get Password: `kubectl get secret -n monitoring grafana-admin-credentials -o jsonpath="{.data.admin-password}" | base64 -d; echo`
    *   Access `https://<grafana-hostname>`, login as `admin`.

4.  **Application UI:**
    *   Get Hostname: `kubectl get ingress -n app app-<region> -o jsonpath='{.spec.rules[0].host}'` (Check actual ingress name, should match `app-<region>.<your-domain>`).
    *   Access `https://<app-hostname>`.

## Stress Testing & Autoscaling (Per Region)

Perform the stress tests outlined previously against the specific Ingress endpoint for the region you want to test. Observe KEDA HPA scaling and Karpenter node provisioning within that regional cluster.

## CI/CD Flow (GitOps with Argo CD)

The CI/CD flow described in the GitHub Actions workflow (`.github/workflows/ci-cd.yaml`) handles building the application container image and updating the Helm chart:

1.  **Trigger:** Pushing changes to the `main` branch affecting `app/`, `helm-chart/app/`, or the workflow file itself triggers the pipeline.
2.  **Build & Push (Multi-Region):**
    *   The workflow checks out the code.
    *   It configures AWS credentials for `us-east-1`, logs into ECR for that region, builds the Docker image from `app/`, tags it with the Git SHA and `latest`, and pushes both tags to the `us-east-1` ECR repository (e.g., `<YOUR_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/eks-blizzard/app`).
    *   It then repeats the configure, login, build, tag, and push steps for the `us-west-2` region, ensuring the same image is available in both regional ECR repositories.
3.  **Helm Chart Update:**
    *   The workflow updates the `image.tag` in `helm-chart/app/values.yaml` to the new Git SHA.
    *   It also updates the `version` and `appVersion` in `helm-chart/app/Chart.yaml`.
4.  **Commit & Push:**
    *   The workflow commits these changes back to the Git repository (`main` branch) with a `[skip ci]` message to prevent triggering itself again.
5.  **Argo CD Sync (Triggered by Git Change):**
    *   Argo CD (running in *both* regions) detects the change in the Git repository (specifically the changes within the `helm-chart/app/` path tracked by the `app` ApplicationSet template).
    *   Each regional Argo CD instance triggers an automatic sync for its `app-<region>` application.
    *   Argo CD re-renders the Helm chart with the updated `values.yaml` (pointing to the new image tag) and applies the changes to the respective regional EKS cluster, resulting in a rolling update of the application deployment in both regions.

## Cleanup (Multi-Region)

To remove all resources created by this project across **both regions**:

1.  **Destroy Terragrunt Resources:**
    *   Navigate to the Terragrunt root directory: `cd terragrunt`
    *   Run the destroy command for all regions:
        ```bash
        terragrunt run-all destroy
        ```
    *   Confirm the destruction for each module in each region by typing `yes` when prompted.

2.  **Manual Cleanup (Check both regions):**
    *   **ECR Repositories:** Delete the `eks-blizzard/app` repository from both `us-east-1` and `us-west-2` ECR consoles.
    *   **ALBs:** Check EC2 Load Balancers in both `us-east-1` and `us-west-2`. Terragrunt should remove the Ingresses, triggering ALB deletion, but verify.
    *   **EBS Volumes:** Check EC2 EBS Volumes in both regions. StatefulSet PVCs might need manual deletion if retain policies were set differently.
    *   **S3 Bucket & DynamoDB Table:** Delete the *single* central S3 bucket and DynamoDB table used for state.
    *   **Secrets Manager:** Check Secrets Manager in **both** `us-east-1` and `us-west-2` for secrets prefixed with `eks-blizzard/` and schedule them for deletion.

## Additional Notes

*   **Multi-Region State:** Terragrunt manages state separately for each region (prefixed by the region name in the S3 key), but uses a single S3 bucket and DynamoDB table for locking.
*   **ACM Certificate:** The current setup references a single ACM certificate ARN (`arn:aws:acm:us-east-1:...`) in both the `us-east-1` and `us-west-2` `region.hcl` files. **This will only work if the certificate is in `us-east-1` and you are using CloudFront or another global service.** For ALBs in `us-west-2`, you would typically need a separate certificate issued in the `us-west-2` region. You would need to adjust the `terragrunt/us-west-2/region.hcl` and potentially the Argo CD/Helm configurations to use the correct regional certificate ARN for the `us-west-2` deployment.
*   **Argo CD Management:** The current setup deploys Argo CD independently within each region's Terragrunt configuration via the `argocd` module defined in `terragrunt/[region]/argocd/terragrunt.hcl`. The `application_sets` block within *each* regional `terragrunt.hcl` defines which applications that specific Argo CD instance will manage *for its region*. Ensure the `cluster` and `url` parameters in the `generators.list.elements` within each ApplicationSet YAML (`argocd/*.yaml`) correctly target the intended cluster for that region's Argo CD instance.
*   **DR/Failover:** This setup provides regional isolation but doesn't include automatic cross-region failover mechanisms (like Route 53 health checks/failover routing or database replication/failover). Implementing those would require additional components and configuration. 