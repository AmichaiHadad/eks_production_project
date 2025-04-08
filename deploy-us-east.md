# Single-Region Deployment Guide (us-east-1)

This guide provides step-by-step instructions for deploying the EKS project in a single region (us-east-1) for testing purposes. This approach reduces costs and complexity while still allowing you to validate the full functionality of the deployment.

## Cost Estimate for Single-Region Deployment

By deploying only in us-east-1, you can expect costs of approximately **$32 USD per day** (~$950 per month), which is 50% of the full multi-region deployment.

## Prerequisites

### Required Tools

Install the following tools on your local machine:

```bash
# Install AWS CLI version 2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl (matching Kubernetes v1.27+)
curl -LO "https://dl.k8s.io/release/v1.27.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Terraform (v1.11.0+)
wget https://releases.hashicorp.com/terraform/1.11.0/terraform_1.11.0_linux_amd64.zip
unzip terraform_1.11.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install Terragrunt (v0.50.0+)
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.50.0/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# Install Helm (v3.12.0+)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install AWS IAM Authenticator
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.0/2023-06-20/bin/linux/amd64/aws-iam-authenticator
chmod +x ./aws-iam-authenticator
sudo mv ./aws-iam-authenticator /usr/local/bin

# Install Git
sudo apt-get update
sudo apt-get install -y git

# Install jq (for JSON processing)
sudo apt-get install -y jq
```

### AWS Account Requirements

1. **AWS Account with Administrator Access**
2. **Service Quotas**:
   - VPCs per region: At least 1
   - Elastic IPs: At least 3 (for NAT Gateways)
   - EC2 instances: At least 10
   - EKS clusters: At least 1

### Required API Keys

1. **Weather API Key**: Register for a free API key at [OpenWeatherMap](https://openweathermap.org/api)
2. **GitHub Personal Access Token** (if setting up CI/CD): Create with `repo` and `packages` scopes

## Step 1: Initial Setup

### Configure AWS CLI

```bash
# Configure AWS CLI with your credentials
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name: us-east-1
- Default output format: json

### Clone the Repository

```bash
git clone https://github.com/yourusername/eks-project-v2.git
cd eks-project-v2
```

## Step 2: Prepare for Terraform/Terragrunt Deployment

### Create S3 Bucket and DynamoDB Table for Terraform State

```bash
# Create S3 bucket
aws s3api create-bucket --bucket eks-blizzard-terragrunt-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning --bucket eks-blizzard-terragrunt-state --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption --bucket eks-blizzard-terragrunt-state --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

# Create DynamoDB table
aws dynamodb create-table \
  --table-name eks-blizzard-terragrunt-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Create KMS Key for EKS Secret Encryption

```bash
# Create KMS key for us-east-1
export KMS_KEY_ID=$(aws kms create-key --description "EKS Secret Encryption Key" --region us-east-1 --query KeyMetadata.KeyId --output text)

# Create alias for easier reference
aws kms create-alias --alias-name alias/eks-blizzard-us-east-1 --target-key-id $KMS_KEY_ID --region us-east-1

# Save key ID for later use
echo "KMS Key for us-east-1: $KMS_KEY_ID"
echo "export KMS_KEY_ID=$KMS_KEY_ID" >> ~/.bashrc
```

### Create ECR Repository

```bash
# Create repository in us-east-1
aws ecr create-repository --repository-name eks-blizzard/app --region us-east-1

# Enable image scanning
aws ecr put-image-scanning-configuration --repository-name eks-blizzard/app --image-scanning-configuration scanOnPush=true --region us-east-1

# Get ECR repository URL
export ECR_REPO=$(aws ecr describe-repositories --repository-names eks-blizzard/app --region us-east-1 --query 'repositories[0].repositoryUri' --output text)
echo "ECR Repository: $ECR_REPO"
echo "export ECR_REPO=$ECR_REPO" >> ~/.bashrc
```

## Step 3: Configure Terragrunt

### Update terragrunt.hcl

Edit the main Terragrunt configuration file:

```bash
# Edit terragrunt.hcl
vim terragrunt/terragrunt.hcl
```

Ensure it contains the following:

```hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "eks-blizzard-terragrunt-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "eks-blizzard-terragrunt-locks"
  }
}

inputs = {}
```

### Update Region Variables

Edit the region-specific configuration:

```bash
# Edit region.hcl for us-east-1
vim terragrunt/us-east-1/region.hcl
```

Ensure the KMS key ID is set:

```hcl
locals {
  region = "us-east-1"
  
  # VPC Configuration
  vpc_cidr = "10.10.0.0/16"
  private_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  public_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  
  # EKS Configuration
  cluster_name = "eks-blizzard-us-east-1"
  kubernetes_version = "1.27"
  kms_key_id = "YOUR_KMS_KEY_ID" # Replace with the KMS key ID you created
  
  # Other regional settings
  tags = {
    Environment = "production"
    Region = "us-east-1"
    Project = "eks-blizzard"
  }
}
```

Replace `YOUR_KMS_KEY_ID` with the actual KMS key ID you created earlier.

## Step 4: Deploy VPC and Networking

Deploy the network infrastructure:

```bash
# Navigate to the networking directory
cd terragrunt/us-east-1/networking

# Initialize Terragrunt
terragrunt init

# Plan the deployment
terragrunt plan

# Apply the configuration
terragrunt apply -auto-approve
```

Wait for approximately 5-10 minutes for VPC creation to complete.

## Step 5: Deploy EKS Cluster

Deploy the EKS control plane:

```bash
# Navigate to the EKS directory
cd ../eks

# Initialize Terragrunt
terragrunt init

# Plan the deployment
terragrunt plan

# Apply the configuration
terragrunt apply -auto-approve
```

This step typically takes 10-15 minutes to complete.

## Step 6: Deploy Node Groups

Deploy the EKS node groups:

```bash
# Navigate to the node-groups directory
cd ../node-groups

# Initialize Terragrunt
terragrunt init

# Plan the deployment
terragrunt plan

# Apply the configuration
terragrunt apply -auto-approve
```

This step typically takes 5-10 minutes to complete.

## Step 7: Configure kubectl

Set up kubectl to interact with your new cluster:

```bash
# Update kubeconfig
aws eks update-kubeconfig --name eks-blizzard-us-east-1 --region us-east-1

# Verify connection
kubectl get nodes

# Test that you can see all node groups
kubectl get nodes --show-labels | grep node-role
```

You should see nodes from all four node groups (monitoring, management, services, data).

## Step 8: Deploy Argo CD

Deploy Argo CD for GitOps:

```bash
# Navigate to the Argo CD directory
cd ../argocd

# Initialize Terragrunt
terragrunt init

# Plan the deployment
terragrunt plan

# Apply the configuration
terragrunt apply -auto-approve
```

Retrieve the initial admin password:

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

# Save it for later use
echo "Argo CD Admin Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
```

## Step 9: Build and Push Application Image

Build and push the application image to ECR:

```bash
# Log in to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO

# Navigate to app directory
cd ../../../app

# Build the application image
docker build -t $ECR_REPO:latest .

# Push to ECR
docker push $ECR_REPO:latest
```

## Step 10: Configure External Secrets

Deploy External Secrets Operator:

```bash
# Store your API key in AWS Secrets Manager
aws secretsmanager create-secret \
    --name eks-blizzard-us-east-1/weather-api \
    --description "Weather API key for EKS application" \
    --secret-string "{\"api_key\":\"YOUR_WEATHER_API_KEY\"}" \
    --region us-east-1

# Navigate to external-secrets directory
cd ../terragrunt/us-east-1/external-secrets

# Initialize Terragrunt
terragrunt init

# Plan the deployment
terragrunt plan

# Apply the configuration
terragrunt apply -auto-approve
```

Replace `YOUR_WEATHER_API_KEY` with your actual OpenWeatherMap API key.

## Step 11: Deploy Network Policies

Deploy Network Policies:

```bash
# Navigate to network-policies directory
cd ../network-policies

# Initialize Terragrunt
terragrunt init

# Plan the deployment
terragrunt plan

# Apply the configuration
terragrunt apply -auto-approve
```

## Step 12: Deploy Security Policies

Deploy Security Policies:

```bash
# Navigate to security-policies directory
cd ../security-policies

# Initialize Terragrunt
terragrunt init

# Plan the deployment
terragrunt plan

# Apply the configuration
terragrunt apply -auto-approve
```

## Step 13: Deploy Stateful Services (MySQL & Elasticsearch)

Deploy stateful services using Argo CD:

```bash
# Apply the ApplicationSet
kubectl apply -f ../../../argocd/stateful-applicationset.yaml

# Wait for the applications to sync
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m

# Verify deployment
kubectl get pods -n default -l app=mysql
kubectl get pods -n default -l app=elasticsearch
```

This step typically takes 2-3 minutes for synchronization and 2-3 more minutes for pods to be ready.

## Step 14: Deploy Application

Deploy the Python Flask application:

```bash
# Update the Helm chart values with the ECR repository
sed -i "s|ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/app|$ECR_REPO|g" ../../../helm-chart/app/values.yaml

# Apply the ApplicationSet
kubectl apply -f ../../../argocd/app-applicationset.yaml

# Wait for the application to sync
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m

# Verify deployment
kubectl get pods -n default -l app=app
kubectl get svc -n default -l app=app
kubectl get ingress -n default -l app=app
```

## Step 15: Deploy Monitoring Stack

Deploy Prometheus, Grafana, and Alertmanager:

```bash
# Apply the ApplicationSet
kubectl apply -f ../../../argocd/monitoring-applicationset.yaml

# Wait for the applications to sync
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m

# Verify deployment
kubectl get pods -n monitoring
```

Get the Grafana admin password:

```bash
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d
echo
```

## Step 16: Deploy Autoscaling Components

Deploy Karpenter and KEDA:

```bash
# Deploy Karpenter
cd ../karpenter
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Deploy KEDA
cd ../keda
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Apply the ApplicationSet
kubectl apply -f ../../../argocd/autoscaling-applicationset.yaml

# Wait for the applications to sync
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m

# Verify deployment
kubectl get pods -n karpenter
kubectl get pods -n keda
```

## Step 17: Deploy Security Components

Deploy Security Components:

```bash
# Apply the ApplicationSet
kubectl apply -f ../../../argocd/security-applicationset.yaml

# Wait for the applications to sync
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m

# Verify deployment
kubectl get pods -n security
```

## Step 18: Test the Deployment

### Access Endpoints

Get the application endpoint:

```bash
APP_ENDPOINT=$(kubectl get ingress -l app=app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "Application is available at: http://$APP_ENDPOINT"
```

Get the Grafana endpoint:

```bash
GRAFANA_ENDPOINT=$(kubectl get ingress -n monitoring grafana -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "Grafana is available at: http://$GRAFANA_ENDPOINT"
```

### Test Autoscaling

Run a load test to verify autoscaling:

```bash
# Apply the load test
kubectl apply -f ../../../testing/load-test.yaml

# Monitor pods and nodes
kubectl get pods -l app=app -w
kubectl get nodes -l provisioning-group=karpenter -w
```

### Test Security

Run the security test script:

```bash
chmod +x ../../../testing/security-tests.sh
../../../testing/security-tests.sh
```

## Cleanup (When Done Testing)

To avoid ongoing costs, clean up resources when you're done testing:

```bash
# First remove ApplicationSets to clean up Argo CD applications
kubectl delete -f ../../../argocd/security-applicationset.yaml
kubectl delete -f ../../../argocd/autoscaling-applicationset.yaml
kubectl delete -f ../../../argocd/monitoring-applicationset.yaml
kubectl delete -f ../../../argocd/app-applicationset.yaml
kubectl delete -f ../../../argocd/stateful-applicationset.yaml

# Now destroy Terraform resources in reverse order
cd ../terragrunt/us-east-1/keda
terragrunt destroy -auto-approve

cd ../karpenter
terragrunt destroy -auto-approve

cd ../security-policies
terragrunt destroy -auto-approve

cd ../network-policies
terragrunt destroy -auto-approve

cd ../external-secrets
terragrunt destroy -auto-approve

cd ../argocd
terragrunt destroy -auto-approve

cd ../node-groups
terragrunt destroy -auto-approve

cd ../eks
terragrunt destroy -auto-approve

cd ../networking
terragrunt destroy -auto-approve
```

## Troubleshooting

If you encounter issues, refer to the DEBUG.md file for detailed debugging steps for each component.

Common issues:

1. **Node groups not joining the cluster**: Check IAM roles and security groups
2. **Application pods pending**: Verify that node groups have sufficient capacity
3. **Argo CD sync failures**: Check git repository access or manifest errors
4. **External Secrets not working**: Verify AWS Secrets Manager permissions

For detailed debugging procedures, see the complete [DEBUG.md](DEBUG.md) guide.

---

This single-region deployment provides the full functionality of the multi-region setup while significantly reducing costs. After testing and validating in us-east-1, you can deploy to us-west-2 following similar steps for a complete production deployment.