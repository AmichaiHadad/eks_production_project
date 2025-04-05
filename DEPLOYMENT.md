# Comprehensive Deployment Guide

This guide provides step-by-step instructions for deploying the Multi-Region AWS EKS Infrastructure & Application Project in its entirety. Follow these instructions carefully to ensure a successful deployment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [AWS Account Configuration](#aws-account-configuration)
4. [Repository Setup](#repository-setup)
5. [Infrastructure Deployment](#infrastructure-deployment)
6. [Application Deployment](#application-deployment)
7. [Monitoring Setup](#monitoring-setup)
8. [Autoscaling Configuration](#autoscaling-configuration)
9. [Security Implementation](#security-implementation)
10. [Validation and Testing](#validation-and-testing)
11. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

Install the following tools on your local machine:

```bash
# AWS CLI version 2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# kubectl (matching your EKS version - 1.27 or higher)
curl -LO "https://dl.k8s.io/release/v1.27.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Terraform (v1.11.0 or higher)
wget https://releases.hashicorp.com/terraform/1.11.0/terraform_1.11.0_linux_amd64.zip
unzip terraform_1.11.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Terragrunt (v0.50.0 or higher)
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.50.0/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# Helm (v3.12.0 or higher)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# AWS IAM Authenticator
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.0/2023-06-20/bin/linux/amd64/aws-iam-authenticator
chmod +x ./aws-iam-authenticator
sudo mv ./aws-iam-authenticator /usr/local/bin

# Git
sudo apt-get update
sudo apt-get install -y git

# Docker (for local development and testing)
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
# Log out and log back in for group changes to take effect

# jq (for JSON processing)
sudo apt-get install -y jq

# yq (for YAML processing)
wget https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_amd64 -O /usr/bin/yq
chmod +x /usr/bin/yq
```

Verify the installations:

```bash
aws --version
kubectl version --client
terraform --version
terragrunt --version
helm version
aws-iam-authenticator version
git --version
docker --version
jq --version
yq --version
```

### AWS Account Requirements

- **AWS Account**: You need an AWS account with administrative permissions
- **IAM User/Role**: Create an IAM user or role with AdministratorAccess (for initial setup)
- **Regions**: Ensure you have access to both us-east-1 and us-west-2 regions
- **Service Quotas**: Check and increase the following service quotas if necessary:
  - VPCs per region: At least 1 per region
  - Elastic IPs: At least 3 per region (for NAT Gateways)
  - EC2 instances: At least 10 per region (for node groups)
  - EKS clusters: At least 1 per region

### Required Keys and Secrets

1. **Weather API Key**: Register for a free API key at [OpenWeatherMap](https://openweathermap.org/api)
2. **GitHub Personal Access Token**: Create a token with `repo` and `packages` scopes for GitHub Actions CI/CD

## Initial Setup

### AWS CLI Configuration

Configure AWS CLI with your credentials:

```bash
aws configure
```

Enter the following information:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name (us-east-1)
- Default output format (json)

Set up a named profile for the second region:

```bash
aws configure --profile us-west-2
```

Enter the same credentials but set the default region to us-west-2.

### Clone the Repository

```bash
git clone https://github.com/yourusername/eks-project-v2.git
cd eks-project-v2
```

## AWS Account Configuration

### Create KMS Keys for Secret Encryption

Create KMS keys in both regions for Kubernetes secret encryption:

```bash
# Create KMS key in us-east-1
aws kms create-key --description "EKS Secret Encryption Key" --region us-east-1
export KMS_KEY_ID_EAST=$(aws kms create-key --description "EKS Secret Encryption Key" --region us-east-1 --query KeyMetadata.KeyId --output text)

# Create KMS key in us-west-2
aws kms create-key --description "EKS Secret Encryption Key" --region us-west-2 --profile us-west-2
export KMS_KEY_ID_WEST=$(aws kms create-key --description "EKS Secret Encryption Key" --region us-west-2 --profile us-west-2 --query KeyMetadata.KeyId --output text)

# Create aliases for easier reference
aws kms create-alias --alias-name alias/eks-blizzard-us-east-1 --target-key-id $KMS_KEY_ID_EAST --region us-east-1
aws kms create-alias --alias-name alias/eks-blizzard-us-west-2 --target-key-id $KMS_KEY_ID_WEST --region us-west-2 --profile us-west-2

# Save these key IDs - you'll need them later
echo "KMS Key for us-east-1: $KMS_KEY_ID_EAST"
echo "KMS Key for us-west-2: $KMS_KEY_ID_WEST"
```

### Create ECR Repositories

Create ECR repositories in both regions:

```bash
# Create repository in us-east-1
aws ecr create-repository --repository-name eks-blizzard/app --region us-east-1

# Create repository in us-west-2
aws ecr create-repository --repository-name eks-blizzard/app --region us-west-2 --profile us-west-2

# Enable image scanning
aws ecr put-image-scanning-configuration --repository-name eks-blizzard/app --image-scanning-configuration scanOnPush=true --region us-east-1
aws ecr put-image-scanning-configuration --repository-name eks-blizzard/app --image-scanning-configuration scanOnPush=true --region us-west-2 --profile us-west-2
```

Get the repository URLs:

```bash
export ECR_REPO_EAST=$(aws ecr describe-repositories --repository-names eks-blizzard/app --region us-east-1 --query 'repositories[0].repositoryUri' --output text)
export ECR_REPO_WEST=$(aws ecr describe-repositories --repository-names eks-blizzard/app --region us-west-2 --profile us-west-2 --query 'repositories[0].repositoryUri' --output text)

echo "ECR Repository for us-east-1: $ECR_REPO_EAST"
echo "ECR Repository for us-west-2: $ECR_REPO_WEST"
```

## Repository Setup

### Configure GitHub Repository

1. Create a new GitHub repository (if not already created)
2. Push the code to the repository:

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/yourusername/eks-project-v2.git
git push -u origin main
```

3. Set up GitHub Actions secrets:
   - Go to your GitHub repository
   - Navigate to Settings > Secrets and variables > Actions
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID`: Your AWS access key
     - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
     - `ECR_REPOSITORY_EAST`: The ECR repository URL for us-east-1
     - `ECR_REPOSITORY_WEST`: The ECR repository URL for us-west-2
     - `WEATHER_API_KEY`: Your OpenWeatherMap API key

## Infrastructure Deployment

We'll deploy the infrastructure in stages, starting with the first region (us-east-1) and then the second region (us-west-2).

### Update Configuration Files

First, update the Terragrunt configuration files with your specific details:

1. Update the main `terragrunt.hcl` file:

```bash
# Edit terragrunt/terragrunt.hcl to match your AWS account details
vim terragrunt/terragrunt.hcl
```

Update the remote state configuration with your S3 bucket name and DynamoDB table:

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
```

2. Create the S3 bucket and DynamoDB table for Terraform state:

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

3. Update region-specific files:

```bash
# Edit region files for us-east-1
vim terragrunt/us-east-1/region.hcl

# Edit region files for us-west-2
vim terragrunt/us-west-2/region.hcl
```

Ensure the KMS key IDs are correctly set in both files.

### Deploy VPC and Networking

First, deploy the VPC and networking components:

```bash
# Deploy us-east-1 networking
cd terragrunt/us-east-1/networking
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Deploy us-west-2 networking
cd ../../us-west-2/networking
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Deploy EKS Clusters

Next, deploy the EKS clusters:

```bash
# Deploy us-east-1 EKS cluster
cd ../../us-east-1/eks
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Deploy us-west-2 EKS cluster
cd ../../us-west-2/eks
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Deploy Node Groups

Deploy the node groups for each cluster:

```bash
# Deploy us-east-1 node groups
cd ../../us-east-1/node-groups
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Deploy us-west-2 node groups
cd ../../us-west-2/node-groups
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Configure kubectl

Set up kubectl to access the clusters:

```bash
# Configure kubectl for us-east-1
aws eks update-kubeconfig --name eks-blizzard-us-east-1 --region us-east-1

# Test connection
kubectl get nodes

# Configure kubectl for us-west-2
aws eks update-kubeconfig --name eks-blizzard-us-west-2 --region us-west-2 --profile us-west-2

# Create a context alias for easier switching
kubectl config rename-context $(kubectl config current-context) us-west-2
kubectl config use-context arn:aws:eks:us-east-1:$(aws sts get-caller-identity --query Account --output text):cluster/eks-blizzard-us-east-1
kubectl config rename-context $(kubectl config current-context) us-east-1

# Verify contexts
kubectl config get-contexts
```

### Deploy Argo CD

Deploy Argo CD to both clusters:

```bash
# Deploy Argo CD to us-east-1
kubectl config use-context us-east-1
cd ../../us-east-1/argocd
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

# Deploy Argo CD to us-west-2
kubectl config use-context us-west-2
cd ../../us-west-2/argocd
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

## Application Deployment

### Configure Application Secrets

Create the required secrets in AWS Secrets Manager:

```bash
# Create Weather API secret in us-east-1
aws secretsmanager create-secret \
    --name eks-blizzard-us-east-1/weather-api \
    --description "Weather API key for EKS application" \
    --secret-string "{\"api_key\":\"$WEATHER_API_KEY\"}" \
    --region us-east-1

# Create Weather API secret in us-west-2
aws secretsmanager create-secret \
    --name eks-blizzard-us-west-2/weather-api \
    --description "Weather API key for EKS application" \
    --secret-string "{\"api_key\":\"$WEATHER_API_KEY\"}" \
    --region us-west-2 --profile us-west-2
```

### Build and Push the Application Image

Build and push the application image to both ECR repositories:

```bash
# Log in to ECR (us-east-1)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO_EAST

# Build the application image
cd app
docker build -t $ECR_REPO_EAST:latest .

# Push to us-east-1 repository
docker push $ECR_REPO_EAST:latest

# Tag and push to us-west-2 repository
docker tag $ECR_REPO_EAST:latest $ECR_REPO_WEST:latest
aws ecr get-login-password --region us-west-2 --profile us-west-2 | docker login --username AWS --password-stdin $ECR_REPO_WEST
docker push $ECR_REPO_WEST:latest
```

### Update Helm Chart Values

Update the application Helm chart values with the ECR repository URLs:

```bash
# Update image repository in values.yaml
cd ../helm-chart/app
sed -i "s|ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/app|$ECR_REPO_EAST|g" values.yaml
```

### Deploy External Secrets Operator

Deploy External Secrets Operator to both clusters:

```bash
# Deploy External Secrets to us-east-1
kubectl config use-context us-east-1
cd ../../terragrunt/us-east-1/external-secrets
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Deploy External Secrets to us-west-2
kubectl config use-context us-west-2
cd ../../us-west-2/external-secrets
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Deploy Stateful Services

Deploy MySQL and Elasticsearch using Argo CD:

```bash
# Apply the Argo CD Application manifests for stateful services
kubectl config use-context us-east-1
kubectl apply -f ../../argocd/stateful-applicationset.yaml

# Check the status
kubectl get applications -n argocd

# Wait for the applications to sync
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m

# Do the same for us-west-2
kubectl config use-context us-west-2
kubectl apply -f ../../argocd/stateful-applicationset.yaml
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m
```

### Deploy the Application

Deploy the Python Flask application using Argo CD:

```bash
# Apply the Argo CD Application manifests for the app
kubectl config use-context us-east-1
kubectl apply -f ../../argocd/app-applicationset.yaml

# Check the status
kubectl get applications -n argocd

# Wait for the application to sync
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m

# Do the same for us-west-2
kubectl config use-context us-west-2
kubectl apply -f ../../argocd/app-applicationset.yaml
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m
```

## Monitoring Setup

### Deploy Monitoring Stack

Deploy Prometheus, Grafana, and Alertmanager using Argo CD:

```bash
# Apply the Argo CD Application manifests for monitoring
kubectl config use-context us-east-1
kubectl apply -f ../../argocd/monitoring-applicationset.yaml

# Check the status
kubectl get applications -n argocd

# Wait for the applications to sync
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m

# Do the same for us-west-2
kubectl config use-context us-west-2
kubectl apply -f ../../argocd/monitoring-applicationset.yaml
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m
```

### Access Grafana

Get the Grafana admin password and URL:

```bash
# us-east-1
kubectl config use-context us-east-1
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d
echo
kubectl get ingress -n monitoring grafana

# us-west-2
kubectl config use-context us-west-2
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d
echo
kubectl get ingress -n monitoring grafana
```

## Autoscaling Configuration

### Deploy Karpenter

Deploy Karpenter to both clusters:

```bash
# Deploy Karpenter to us-east-1
kubectl config use-context us-east-1
cd ../../terragrunt/us-east-1/karpenter
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Deploy Karpenter to us-west-2
kubectl config use-context us-west-2
cd ../../us-west-2/karpenter
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Deploy KEDA

Deploy KEDA to both clusters:

```bash
# Deploy KEDA to us-east-1
kubectl config use-context us-east-1
cd ../../us-east-1/keda
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Deploy KEDA to us-west-2
kubectl config use-context us-west-2
cd ../../us-west-2/keda
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Deploy Autoscaling Configuration

Deploy the autoscaling configuration using Argo CD:

```bash
# Apply the Argo CD Application manifests for autoscaling
kubectl config use-context us-east-1
kubectl apply -f ../../argocd/autoscaling-applicationset.yaml

# Check the status
kubectl get applications -n argocd

# Wait for the applications to sync
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m

# Do the same for us-west-2
kubectl config use-context us-west-2
kubectl apply -f ../../argocd/autoscaling-applicationset.yaml
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m
```

## Security Implementation

### Deploy Network Policies

Deploy Network Policies to both clusters:

```bash
# Deploy Network Policies to us-east-1
kubectl config use-context us-east-1
cd ../../terragrunt/us-east-1/network-policies
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Deploy Network Policies to us-west-2
kubectl config use-context us-west-2
cd ../../us-west-2/network-policies
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Deploy Security Policies

Deploy Security Policies to both clusters:

```bash
# Deploy Security Policies to us-east-1
kubectl config use-context us-east-1
cd ../../us-east-1/security-policies
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Deploy Security Policies to us-west-2
kubectl config use-context us-west-2
cd ../../us-west-2/security-policies
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Deploy Security Components

Deploy security components using Argo CD:

```bash
# Apply the Argo CD Application manifests for security
kubectl config use-context us-east-1
kubectl apply -f ../../argocd/security-applicationset.yaml

# Check the status
kubectl get applications -n argocd

# Wait for the applications to sync
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m

# Do the same for us-west-2
kubectl config use-context us-west-2
kubectl apply -f ../../argocd/security-applicationset.yaml
kubectl wait --for=condition=Synced applications -n argocd --all --timeout=5m
```

## Validation and Testing

### Validate Application Deployment

Check that the application is running correctly:

```bash
# Check application pods in us-east-1
kubectl config use-context us-east-1
kubectl get pods -l app=app
kubectl get svc -l app=app
kubectl get ingress -l app=app

# Test the application endpoint
ENDPOINT=$(kubectl get ingress -l app=app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
curl -v http://$ENDPOINT

# Check application pods in us-west-2
kubectl config use-context us-west-2
kubectl get pods -l app=app
kubectl get svc -l app=app
kubectl get ingress -l app=app

# Test the application endpoint
ENDPOINT=$(kubectl get ingress -l app=app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
curl -v http://$ENDPOINT
```

### Test Autoscaling

Test the autoscaling functionality:

```bash
# Apply the load test in us-east-1
kubectl config use-context us-east-1
kubectl apply -f ../../testing/load-test.yaml

# Monitor the pods and nodes
kubectl get pods -l app=app -w
kubectl get nodes -l provisioning-group=karpenter -w
```

### Test Security

Run the security test script:

```bash
# Run the security test in us-east-1
kubectl config use-context us-east-1
chmod +x ../../testing/security-tests.sh
../../testing/security-tests.sh
```

## DNS Configuration (Optional)

For a production setup, you might want to configure DNS:

1. Create a Route53 hosted zone for your domain (if you don't already have one)
2. Create A records for your application and services pointing to the ALB endpoints
3. Set up latency-based routing or failover routing between the two regions

```bash
# Get the ALB endpoints
kubectl config use-context us-east-1
EAST_ENDPOINT=$(kubectl get ingress -l app=app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

kubectl config use-context us-west-2
WEST_ENDPOINT=$(kubectl get ingress -l app=app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

echo "East endpoint: $EAST_ENDPOINT"
echo "West endpoint: $WEST_ENDPOINT"
```

Then use the AWS Console or CLI to create the necessary DNS records.

## Troubleshooting

### Common Issues and Solutions

1. **EKS Cluster Creation Fails**:
   - Check IAM permissions
   - Ensure the AWS CLI is correctly configured
   - Verify service quota limits

   ```bash
   # Check the CloudFormation stack events
   aws cloudformation describe-stack-events --stack-name eks-blizzard-us-east-1 --region us-east-1
   ```

2. **Node Groups Fail to Join the Cluster**:
   - Check security group configuration
   - Verify IAM roles and policies
   - Check the node bootstrap logs

   ```bash
   # Get the node instance IDs
   aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/eks-blizzard-us-east-1,Values=owned" --query "Reservations[*].Instances[*].InstanceId" --output text --region us-east-1
   
   # Check the system logs for a specific instance
   aws ec2 get-console-output --instance-id i-0123456789abcdef0 --region us-east-1
   ```

3. **External Secrets Operator Issues**:
   - Check IAM role permissions
   - Verify Secret Manager secrets are correctly formatted
   - Check pod logs

   ```bash
   kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
   ```

4. **Argo CD Sync Failures**:
   - Check the Application status and sync errors
   - Verify that the Git repository is accessible
   - Check the Argo CD logs

   ```bash
   kubectl -n argocd get applications
   kubectl -n argocd describe application <app-name>
   kubectl -n argocd logs -l app.kubernetes.io/name=argocd-server
   ```

5. **Networking Issues**:
   - Verify VPC configuration (subnets, route tables, etc.)
   - Check security group rules
   - Test connectivity between components

   ```bash
   # Run a network debug pod
   kubectl run -it --rm debug --image=nicolaka/netshoot -- /bin/bash
   ```

6. **Pod Startup Failures**:
   - Check pod events and logs
   - Verify resource requirements and limits
   - Check node capacity and resource availability

   ```bash
   kubectl describe pod <pod-name>
   kubectl logs <pod-name>
   kubectl get events --sort-by='.lastTimestamp'
   ```

### Getting Support

If you encounter issues not covered by this troubleshooting guide, you can:

1. Check the AWS EKS documentation: https://docs.aws.amazon.com/eks/
2. Search the Kubernetes documentation: https://kubernetes.io/docs/
3. File an issue in the GitHub repository: https://github.com/yourusername/eks-project-v2/issues

## Maintenance and Updates

### Regular Maintenance Tasks

1. **Update EKS Cluster Version**:
   ```bash
   # Update cluster version in the terragrunt configuration and apply
   cd terragrunt/us-east-1/eks
   terragrunt apply
   ```

2. **Update Node AMIs**:
   ```bash
   # Update node AMI IDs in the terragrunt configuration and apply
   cd terragrunt/us-east-1/node-groups
   terragrunt apply
   ```

3. **Update Application**:
   ```bash
   # Build and push a new application version
   cd app
   docker build -t $ECR_REPO_EAST:v2 .
   docker push $ECR_REPO_EAST:v2
   
   # Update the Helm chart values
   cd ../helm-chart/app
   sed -i "s|tag: latest|tag: v2|g" values.yaml
   git add values.yaml
   git commit -m "Update application version to v2"
   git push
   ```

4. **Monitor for Security Updates**:
   Regularly check for security advisories and updates for:
   - AWS EKS
   - Kubernetes
   - Container images
   - Third-party components

5. **Review and Rotate Secrets**:
   Periodically rotate credentials and secrets:
   ```bash
   # Update secrets in AWS Secrets Manager
   aws secretsmanager update-secret --secret-id eks-blizzard-us-east-1/weather-api --secret-string "{\"api_key\":\"NEW_API_KEY\"}" --region us-east-1
   ```

## Conclusion

Congratulations! You have successfully deployed the Multi-Region AWS EKS Infrastructure & Application Project. This deployment provides a robust, scalable, and secure Kubernetes environment across two AWS regions.

For security best practices and update management procedures, refer to the [SECURITY-BEST-PRACTICES.md](docs/SECURITY-BEST-PRACTICES.md) document.

For information about autoscaling, refer to the [AUTOSCALING.md](docs/AUTOSCALING.md) document.