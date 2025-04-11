# Single-Region Deployment Guide (us-east-1)

This guide provides step-by-step instructions for deploying the EKS project in a single region (`us-east-1`) for testing or development purposes. This approach reduces costs and complexity while still allowing you to validate the full functionality of the deployment.

> ⚠️ **COST WARNING**: Running even a single region of this infrastructure involves costs for EKS control plane, EC2 instances, NAT Gateways, EBS volumes, Load Balancers, etc. Ensure you monitor costs and destroy resources when finished.

## Prerequisites

### Required Tools

Install the following tools on your local machine:

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

### AWS Account Requirements

1.  **AWS Account**: With permissions to create VPCs, EKS clusters, IAM roles, EC2 instances, Load Balancers, S3, DynamoDB, KMS, ECR, Secrets Manager, Route 53.
2.  **Service Quotas**: Ensure sufficient quotas for the resources mentioned above in the `us-east-1` region.

### Required Secrets & Keys

1.  **Weather API Key**: Obtain a free API key from [OpenWeatherMap](https://openweathermap.org/api).

## Step 1: Initial Setup

### Configure AWS CLI

Configure your default AWS CLI profile to point to `us-east-1`:

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region name: us-east-1
# Default output format: json
```

### Clone the Repository

```bash
git clone https://github.com/AmichaiHadad/eks_app_2.git # Replace with your repo URL if forked
cd eks_app_2
```

## Step 2: AWS Pre-configuration (us-east-1)

### Create S3 Bucket and DynamoDB Table for Terragrunt State

These resources are used by Terragrunt to manage Terraform state remotely and handle locking.

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

### Create KMS Key for EKS Secret Encryption

This key encrypts Kubernetes secrets within the EKS control plane.

```bash
AWS_REGION="us-east-1"
KMS_KEY_ALIAS="alias/eks-blizzard-us-east-1-key"

# Create KMS key
KMS_KEY_ID=$(aws kms create-key --description "EKS Secret Encryption Key us-east-1" --region ${AWS_REGION} --query KeyMetadata.KeyId --output text)

# Create alias
aws kms create-alias --alias-name ${KMS_KEY_ALIAS} --target-key-id ${KMS_KEY_ID} --region ${AWS_REGION}

# Store the Key ID for later use
export KMS_KEY_ID_EAST=${KMS_KEY_ID}
echo "KMS Key for us-east-1: ${KMS_KEY_ID_EAST}"
```

### Create ECR Repository

This repository will store your application's Docker image.

```bash
AWS_REGION="us-east-1"
ECR_REPO_NAME="eks-blizzard/app"

# Create repository
aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION}

# Enable image scanning
aws ecr put-image-scanning-configuration --repository-name ${ECR_REPO_NAME} --image-scanning-configuration scanOnPush=true --region ${AWS_REGION}

# Get ECR repository URL
export ECR_REPO_EAST=$(aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${AWS_REGION} --query 'repositories[0].repositoryUri' --output text)
echo "ECR Repository us-east-1: ${ECR_REPO_EAST}"
```

## Step 3: Configure Terragrunt

### Update Root `terragrunt.hcl`

Edit the main Terragrunt configuration file `terragrunt/terragrunt.hcl` and ensure the `remote_state` block matches the S3 bucket and DynamoDB table created in Step 2.

```hcl
# terragrunt/terragrunt.hcl
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "YOUR_UNIQUE_BUCKET_NAME" # <-- Update this
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1" # Set appropriately
    encrypt        = true
    dynamodb_table = "YOUR_DYNAMODB_TABLE_NAME" # <-- Update this
  }
}

# ... rest of the file ...
```
Replace `YOUR_UNIQUE_BUCKET_NAME` and `YOUR_DYNAMODB_TABLE_NAME` with the names you used.

### Update `us-east-1/region.hcl`

Edit the region-specific configuration file `terragrunt/us-east-1/region.hcl` and insert the KMS Key ID created in Step 2.

```hcl
# terragrunt/us-east-1/region.hcl
locals {
  # ... other variables ...
  
  # EKS Configuration
  # ...
  kms_key_id = "YOUR_KMS_KEY_ID_EAST" # <-- Update this
  
  # ... other variables ...
  
  # TLS certificate for HTTPS (Ensure this is correct for us-east-1)
  acm_certificate_arn = "arn:aws:acm:us-east-1:163459217187:certificate/4ff90f30-64f8-40e1-b1b3-8f13d5fac876"
}
```
Replace `YOUR_KMS_KEY_ID_EAST` with the actual KMS key ID (e.g., `7032bea8-c4ca-4fd7-9f9e-1a19fd6fb72a`).

## Step 4: Deploy Infrastructure (Terragrunt Apply - us-east-1)

Deploy the core infrastructure components using Terragrunt. Apply modules in the specified order due to dependencies.

**Important:** Run these commands from the root of the repository.

```bash
# 1. Deploy Networking (VPC, Subnets, etc.)
terragrunt run-all apply --working-dir=terragrunt/us-east-1/networking --non-interactive

# 2. Deploy EKS Cluster Control Plane
terragrunt run-all apply --working-dir=terragrunt/us-east-1/eks --non-interactive
# 3. Deploy EKS Node Groups
terragrunt run-all apply --working-dir=terragrunt/us-east-1/node-groups --non-interactive

# 4. Deploy EKS Addons (CNI, CoreDNS, EBS CSI, IRSA roles)
terragrunt run-all apply --working-dir=terragrunt/us-east-1/eks-addons --non-interactive

# 5. Deploy External Secrets (Creates AWS Secrets, Deploys ESO)
# Note: Requires Weather API Key as input (edit terragrunt.hcl or use env var TF_VAR_weather_api_key)
echo "Ensure WEATHER_API_KEY is set in terragrunt/us-east-1/external-secrets/terragrunt.hcl or as TF_VAR_weather_api_key"
export TF_VAR_weather_api_key="YOUR_WEATHER_API_KEY" # Set your actual key
export TF_VAR_slack_webhook_url="YOUR_SLACK_WEBHOOK_URL" # Set your actual webhook URL
terragrunt run-all apply --working-dir=terragrunt/us-east-1/external-secrets --non-interactive

# 6. Deploy Argo CD (Includes AWS LB Controller)
terragrunt run-all apply --working-dir=terragrunt/us-east-1/argocd --non-interactive

# 7. Deploy Karpenter Controller
terragrunt run-all apply --working-dir=terragrunt/us-east-1/karpenter --non-interactive

# 8. Deploy KEDA Controller
terragrunt run-all apply --working-dir=terragrunt/us-east-1/keda --non-interactive

# 9. Deploy Trivy Operator
terragrunt run-all apply --working-dir=terragrunt/us-east-1/trivy-operator --non-interactive

# 10. Deploy Network Policies
terragrunt run-all apply --working-dir=terragrunt/us-east-1/network-policies --non-interactive

# 11. Deploy Security Policies (PSS, Audit, Polaris)
terragrunt run-all apply --working-dir=terragrunt/us-east-1/security-policies --non-interactive
```

**Note on External Secrets:** The `external-secrets` Terragrunt module uses a `null_resource` with `local-exec` to manage secrets in AWS Secrets Manager (force-deleting if they exist before creating). Ensure your AWS CLI has permissions for `secretsmanager:DescribeSecret` and `secretsmanager:DeleteSecret`. Make sure to replace the placeholder values for `weather_api_key` and `slack_webhook_url` in `terragrunt/us-east-1/external-secrets/terragrunt.hcl` or pass them as Terraform variables (e.g., using `TF_VAR_...` environment variables).

## Step 5: Configure kubectl

Set up kubectl to interact with your new EKS cluster.

```bash
CLUSTER_NAME="eks-blizzard-us-east-1"
AWS_REGION="us-east-1"

# Update kubeconfig
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}

# Verify connection
kubectl get nodes -o wide

# Verify node groups (should show nodes with different roles)
kubectl get nodes --show-labels | grep 'node-role='
```

You should see nodes from the monitoring, management, services, and data node groups.

## Step 6: Argo CD Post-Setup

Retrieve the initial Argo CD admin password.

```bash
ARGO_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Argo CD Admin Password: ${ARGO_PASS}"
echo "(Save this password securely. You should change it after first login.)"

# Get Argo CD Ingress URL
ARGO_URL=$(kubectl get ingress -n argocd argocd-server -o jsonpath='{.spec.rules[0].host}')
echo "Argo CD UI: https://${ARGO_URL}"
```
Access the Argo CD UI via the provided URL and log in with username `admin` and the retrieved password.

## Step 7: Build and Push Application Image

Build the application Docker image and push it to the ECR repository created earlier.

```bash
AWS_REGION="us-east-1"

# Ensure ECR_REPO_EAST is set from Step 2
echo ${ECR_REPO_EAST}

# Log in to ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_EAST}

# Navigate to app directory
cd app

# Build the application image (using git sha as tag for uniqueness)
IMAGE_TAG=$(git rev-parse --short HEAD)
docker build -t ${ECR_REPO_EAST}:${IMAGE_TAG} -t ${ECR_REPO_EAST}:latest .

# Push to ECR
docker push ${ECR_REPO_EAST}:${IMAGE_TAG}
docker push ${ECR_REPO_EAST}:latest

cd .. # Return to project root
```

## Step 8: Update Helm Chart Values

Update the application Helm chart to use the correct ECR repository URL and the latest image tag.

```bash
AWS_REGION="us-east-1"
IMAGE_TAG=$(git rev-parse --short HEAD)

# Update image repository and tag in helm-chart/app/values.yaml
sed -i "s|ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/app|${ECR_REPO_EAST}|g" helm-chart/app/values.yaml
sed -i "s|tag: latest|tag: ${IMAGE_TAG}|g" helm-chart/app/values.yaml

# Update app ingress host (certificate ARN is now passed dynamically if needed)
# sed -i "s|host: app.blizzard.co.il|host: app.${AWS_REGION}.blizzard.co.il|g" helm-chart/app/values.yaml # Hostname is set by ApplicationSet parameter
# sed -i "/alb.ingress.kubernetes.io\/certificate-arn:/c\    alb.ingress.kubernetes.io/certificate-arn: $(grep acm_certificate_arn terragrunt/us-east-1/region.hcl | cut -d \" -f2)" helm-chart/app/values.yaml # Cert ARN is set by ApplicationSet parameter

echo "Note: Secret names (e.g., for Weather API, DB creds) are passed dynamically via Argo CD ApplicationSets and should not be manually set in values.yaml for this flow."

# Commit these changes (optional, but recommended for GitOps consistency if manual image update is done)
REPO_URL=$(git remote get-url origin)
sed -i "s|https://github.com/AmichaiHadad/eks_app_2.git|${REPO_URL}|g" argocd/*.yaml

echo "Applying ApplicationSets. Dynamic AWS secret names generated by Terraform (external-secrets module)"
echo "are passed through Terragrunt (argocd module) to these ApplicationSets,"
echo "which then inject them as parameters into the Helm charts (app, mysql, monitoring)."
```

## Step 9: Kubernetes Pre-configuration (Secrets)

Before deploying monitoring, create necessary secrets in the `monitoring` namespace.

```bash
# Create monitoring namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Create the Slack webhook secret for Alertmanager - REMOVED (Handled by ESO)
# ... (removed Slack secret retrieval and kubectl create secret)

echo "Slack secret creation skipped (managed by ESO)."

# Create Grafana admin credentials secret - REMOVED (Handled by ESO)
# GRAFANA_PASSWORD=$(openssl rand -base64 16)
# echo "Generated Grafana password: ${GRAFANA_PASSWORD}"
# echo "(Save this password securely! It will be stored in AWS Secrets Manager)"
# 
# kubectl create secret generic grafana-admin-credentials \
#   -n monitoring \
#   --from-literal=admin-user="admin" \
#   --from-literal=admin-password="${GRAFANA_PASSWORD}" \
#   --dry-run=client -o yaml | kubectl apply -f -

echo "Grafana admin secret creation skipped (managed by ESO)."
```

## Step 10: Deploy Kubernetes Workloads via Argo CD

Apply the Argo CD ApplicationSet manifests to deploy the remaining Kubernetes workloads. Argo CD will manage the Helm deployments based on the configurations in Git.

```bash
# Note: Ensure your Git repo URL is correct in the ApplicationSet files if you forked the project.
REPO_URL=$(git remote get-url origin)
sed -i "s|https://github.com/AmichaiHadad/eks_app_2.git|${REPO_URL}|g" argocd/*.yaml

# 1. Deploy Stateful Services (MySQL, Elasticsearch, Fluentd)
kubectl apply -f argocd/stateful-applicationset.yaml
echo "Waiting for stateful services to sync and become healthy (this may take several minutes)..."
kubectl wait --for=condition=Healthy applicationset/stateful-services -n argocd --timeout=10m

# 2. Deploy Application
kubectl apply -f argocd/app-applicationset.yaml
echo "Waiting for application to sync and become healthy..."
kubectl wait --for=condition=Healthy applicationset/app -n argocd --timeout=5m

# 3. Deploy Monitoring Stack
kubectl apply -f argocd/monitoring-applicationset.yaml
echo "Waiting for monitoring stack to sync and become healthy..."
kubectl wait --for=condition=Healthy applicationset/monitoring -n argocd --timeout=10m

# Get Grafana Endpoint
GRAFANA_HOST=$(kubectl get ingress -n monitoring grafana -o jsonpath='{.spec.rules[0].host}')
echo "Grafana URL: https://${GRAFANA_HOST}"
# Retrieve password from Secrets Manager for user info
GRAFANA_PASSWORD_INFO=$(aws secretsmanager get-secret-value --secret-id eks-blizzard/grafana-admin --query SecretString --output text --region us-east-1 | jq -r ' .\"admin-password\" ')
echo "Grafana Password: ***Retrieved from AWS Secrets Manager*** (use 'aws secretsmanager get-secret-value --secret-id eks-blizzard/grafana-admin' to view)"

# 4. Deploy Autoscaling Configuration (Karpenter Provisioner, KEDA ScaledObject)
kubectl apply -f argocd/autoscaling-applicationset.yaml
echo "Waiting for autoscaling components to sync and become healthy..."
kubectl wait --for=condition=Healthy applicationset/autoscaling-components -n argocd --timeout=5m

# 5. Security ApplicationSet - SKIPPED
# Note: Security components (ESO, Polaris, Trivy Operator) and policies (PSS, Audit, NetworkPolicies) 
# are now primarily deployed via Terragrunt modules (external-secrets, trivy-operator, network-policies, security-policies).
# Applying argocd/security-applicationset.yaml would cause conflicts.
echo "Skipping security-applicationset.yaml as components are managed by Terragrunt."
# # kubectl apply -f argocd/security-applicationset.yaml
# # echo "Waiting for security components to sync..."
# # kubectl wait --for=condition=Healthy applicationset/security-components -n argocd --timeout=5m
```

## Step 11: Validation and Testing

### Access Endpoints

Get the public endpoints for the deployed services.

```bash
# Get Application Endpoint
APP_HOST=$(kubectl get ingress -n app -l app.kubernetes.io/name=app -o jsonpath='{.items[0].spec.rules[0].host}')
echo "Application URL: https://${APP_HOST}"

# Get Argo CD Endpoint
ARGO_HOST=$(kubectl get ingress -n argocd argocd-server -o jsonpath='{.spec.rules[0].host}')
echo "Argo CD URL: https://${ARGO_HOST}"
echo "Argo CD Password: ${ARGO_PASS}"

# Get Grafana Endpoint
GRAFANA_HOST=$(kubectl get ingress -n monitoring grafana -o jsonpath='{.spec.rules[0].host}')
echo "Grafana URL: https://${GRAFANA_HOST}"
echo "Grafana Password: ${GRAFANA_PASSWORD_INFO}"
```

Access these URLs in your browser. Note that DNS propagation might take a few minutes.

### Test Application

```bash
curl -k https://${APP_HOST}
# Check the output for client IP, welcome message, container ID, and temperature.
```

### Test Autoscaling

Apply the load test job and monitor the application pods and Karpenter nodes.

```bash
# Apply the load test
kubectl apply -f testing/load-test.yaml

# Monitor pods (expect replicas to increase beyond 2)
kubectl get pods -n app -l app.kubernetes.io/name=app -w

# Monitor HPA created by KEDA
kubectl get hpa -n app keda-hpa-app -w

# Monitor nodes created by Karpenter (look for nodes labeled 'provisioning-group=karpenter')
kubectl get nodes -l provisioning-group=karpenter -w

# Clean up load test job when done
kubectl delete job -n app load-test
```

### Test Security

Run the provided security testing script.

```bash
chmod +x testing/security-tests.sh
./testing/security-tests.sh
```
Review the output for any security check failures.

# Note: Ensure Trivy Operator pods are running in trivy-system namespace:
# kubectl get pods -n trivy-system

## Cleanup (Destruction Flow)

To avoid ongoing costs, destroy all resources when you are finished testing.

**Important:** Follow the destruction steps carefully in reverse order of creation.

```bash
# 1. Delete ArgoCD ApplicationSets (Reverse Order of Deployment)
# This tells ArgoCD to remove the deployed Kubernetes resources.
kubectl delete -f argocd/autoscaling-applicationset.yaml
kubectl delete -f argocd/monitoring-applicationset.yaml
kubectl delete -f argocd/app-applicationset.yaml
kubectl delete -f argocd/stateful-applicationset.yaml
echo "Waiting for ArgoCD to prune resources (may take a few minutes)..."
sleep 180 # Allow time for resource deletion

# 2. Destroy Infrastructure using Terragrunt (Reverse Order of Apply)
# Run from the root of the repository.
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/security-policies --terragrunt-non-interactive
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/network-policies --terragrunt-non-interactive
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/trivy-operator --terragrunt-non-interactive
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/keda --terragrunt-non-interactive
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/karpenter --terragrunt-non-interactive
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/argocd --terragrunt-non-interactive
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/external-secrets --terragrunt-non-interactive
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/eks-addons --terragrunt-non-interactive
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/node-groups --terragrunt-non-interactive
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/eks --terragrunt-non-interactive
terragrunt run-all destroy --terragrunt-working-dir terragrunt/us-east-1/networking --terragrunt-non-interactive

# 3. Clean up AWS Pre-configuration Resources
AWS_REGION="us-east-1"
TF_STATE_BUCKET="eks-blizzard-terragrunt-state-$(aws sts get-caller-identity --query Account --output text)"
TF_LOCK_TABLE="eks-blizzard-terragrunt-locks"
ECR_REPO_NAME="eks-blizzard/app"
KMS_KEY_ALIAS="alias/eks-blizzard-us-east-1-key"

echo "Cleaning up ECR repository..."
aws ecr delete-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION} --force || echo "ECR repo already deleted or never existed."

echo "Cleaning up KMS key..."
KMS_KEY_ID=$(aws kms describe-key --key-id ${KMS_KEY_ALIAS} --region ${AWS_REGION} --query KeyMetadata.KeyId --output text 2>/dev/null)
if [ ! -z "$KMS_KEY_ID" ]; then
  aws kms schedule-key-deletion --key-id ${KMS_KEY_ID} --pending-window-in-days 7 --region ${AWS_REGION} || echo "KMS key already scheduled for deletion or alias not found."
else
  echo "KMS key or alias not found."
fi

echo "Cleaning up S3 state bucket..."
aws s3 rb s3://${TF_STATE_BUCKET} --force || echo "S3 bucket already deleted or never existed."

echo "Cleaning up DynamoDB lock table..."
aws dynamodb delete-table --table-name ${TF_LOCK_TABLE} --region ${AWS_REGION} || echo "DynamoDB table already deleted or never existed."

# Clean up secrets created by external-secrets module
# Note: The null_resource tries to delete these during destroy, but manual cleanup might be needed if that fails.
echo "Attempting to cleanup Secrets Manager secrets (might fail if already deleted)..."
aws secretsmanager delete-secret --secret-id eks-blizzard-us-east-1/mysql --force-delete-without-recovery --region ${AWS_REGION} || true
aws secretsmanager delete-secret --secret-id eks-blizzard-us-east-1/weather-api --force-delete-without-recovery --region ${AWS_REGION} || true
aws secretsmanager delete-secret --secret-id eks-blizzard-us-east-1/slack-webhook --force-delete-without-recovery --region ${AWS_REGION} || true

echo "Cleanup complete."
```

## Troubleshooting

Refer to the [DEBUG.md](DEBUG.md) guide for detailed troubleshooting steps for each component.

---

This updated guide provides a more accurate flow for deploying the project in `us-east-1`, incorporating the dependencies and specific configurations identified in the project files.