# EKS Blizzard Cluster Deployment Guide: US-East-1

This guide outlines the steps required to deploy the EKS Blizzard infrastructure in the US-East-1 region. The deployment uses Terragrunt to manage Terraform configurations and state.

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

## Required Environment Variables

Set the following environment variables before starting the deployment:

```bash
# Required variables for external-secrets module
export TF_VAR_weather_api_key="your-weather-api-key"
export TF_VAR_slack_webhook_url="your-slack-webhook-url" 
```

## Deployment Order

The components should be deployed in the following order to ensure proper dependency resolution:

1. **Networking**: VPC, Subnets, Security Groups
2. **EKS**: Kubernetes Cluster
3. **Node Groups**: EC2 Node Groups for different workloads
4. **EKS Addons**: VPC CNI, CoreDNS, Kube Proxy, etc.
5. **External Secrets**: Secret management using AWS Secrets Manager
6. **Namespaces**: Kubernetes Namespaces
7. **ArgoCD**: GitOps deployment tool
8. **Karpenter**: Node autoscaling
9. **KEDA**: Kubernetes Event-driven Autoscaling
10. **Trivy Operator**: Security scanning
11. **Network Policies**: Network security policies
12. **Security Policies**: Additional security policies

## All-at-once Deployment with Forced Sequential Execution

If you want to deploy all modules at once, you can force sequential execution by using the `--terragrunt-parallelism 1` flag:

```bash
cd terragrunt/us-east-1
terragrunt run-all apply --terragrunt-parallelism 1 --non-interactive
```

This will ensure modules are applied one at a time in the correct dependency order. The default parallelism behavior in Terragrunt runs modules concurrently when their direct dependencies are satisfied, which can lead to issues when implicit dependencies exist (like KEDA needing the app namespace to exist).

## Verifying the Deployment

After the deployment is complete, you can verify access to your EKS cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-blizzard-us-east-1
kubectl get nodes
```

Access ArgoCD UI:

```bash
# Get the ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Get the ArgoCD Ingress URL: 
kubectl -n argocd get ingress
```

## Deploying ArgoCD ApplicationSets

After ArgoCD is installed, deploy the ApplicationSets in the following order:

1. **CRD ApplicationSet**:
```bash
    kubectl apply -f argocd/crd-applicationset.yaml 
```
2. **Stateful ApplicationSet**:
```bash
    kubectl apply -f argocd/stateful-applicationset.yaml 
```
2. **Monitoring ApplicationSet**:
```bash
    kubectl apply -f argocd/monitoring-applicationset.yaml 
```
2. **Python-App ApplicationSet**:
```bash
    kubectl apply -f argocd/app-applicationset.yaml 
```

## Understanding Deployment Dependencies

The deployment dependencies are configured as follows:

1. `networking`: No dependencies
2. `eks`: Depends on `networking`
3. `node-groups`: Depends on `networking` and `eks`
4. `eks-addons`: Depends on `networking`, `eks`, and `node-groups`
5. `external-secrets`: Depends on `eks-addons`
6. `namespaces`: Depends on `eks`
7. `argocd`: Depends on `namespaces`
8. `karpenter`: Depends on `eks`, `node-groups`, `networking` and `argocd`
9. `keda`: Depends on `karpenter` and `namespaces`
10. `trivy-operator`: Depends on `keda`
11. `network-policies`: Depends on `trivy-operator`
12. `security-policies`: Depends on `network-policies`

These dependencies determine the order in which modules are applied. However, some modules have implicit dependencies that aren't captured in the terragrunt.hcl files. For example, KEDA creates resources in the `app` namespace, which is created by ArgoCD based on application definitions.

## Cleanup

To destroy the infrastructure, run in reverse order:

```bash
cd terragrunt/us-east-1
terragrunt run-all destroy --terragrunt-parallelism 1
```

This will destroy all resources created by Terragrunt. 