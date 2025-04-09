# Security Best Practices and Update Management

This document outlines the security best practices and update management procedures for the EKS Blizzard infrastructure.

## Security Components

### 1. External Secrets Operator (ESO)

External Secrets Operator is deployed to securely access and manage secrets from AWS Secrets Manager:

- **Authentication**: ESO uses IAM Roles for Service Accounts (IRSA) for authentication
- **Secret Rotation**: AWS Secrets Manager automatically rotates secrets as configured
- **Usage**: Application components reference ExternalSecret resources instead of creating Kubernetes Secrets directly

### 2. Network Policies

Zero-trust network policy model is implemented:

- **Default Deny**: All namespaces have a default deny policy for both ingress and egress
- **Selective Access**: Only specific, required connections between services are allowed
- **DNS Access**: All pods are allowed access to kube-dns for name resolution
- **External Access**: Restricted to specific services that need it (e.g., External Secrets Operator)

### 3. Pod Security Standards

Kubernetes Pod Security Standards are enforced at the namespace level:

- **Restricted Profile**: Applied to all application namespaces
- **Enforcement**: Applied using both audit and enforce modes
- **Capabilities**: Restricted to minimum required set

### 4. Security Scanning

Security scanning is implemented via:

- **Trivy Operator**: Scans container images for vulnerabilities
- **Polaris**: Validates Kubernetes resources against best practices
- **ECR Scanning**: Automatic scanning of images in ECR repositories

### 5. Audit Logging

Comprehensive audit logging is enabled:

- **API Server Audit Policy**: Records all sensitive operations
- **CloudWatch Logs**: EKS control plane logs are sent to CloudWatch
- **Log Retention**: 30 days for audit logs

## Update Management

### 1. Kubernetes Version Updates

Kubernetes version updates should follow this procedure:

1. **Pre-update Tasks**:
   - Review compatibility of all installed components with the new EKS version
   - Take snapshot backups of EBS volumes for stateful workloads
   - Document current deployment state using `kubectl get all -A`

2. **Update Order**:
   - First update the EKS control plane
   - Then update node groups one by one, starting with the non-critical workloads

3. **Update Commands**:
   ```bash
   # Update EKS control plane (via terragrunt)
   cd terragrunt/us-east-1/eks
   terragrunt plan  # Review the plan
   terragrunt apply  # Apply the update
   
   # Update node groups (via terragrunt)
   cd terragrunt/us-east-1/node-groups
   terragrunt plan  # Review the plan
   terragrunt apply  # Apply the update
   ```

4. **Post-update Tasks**:
   - Verify all workloads are running correctly
   - Check logs for any errors
   - Test application functionality

### 2. Node AMI Updates

Worker nodes should be regularly updated to receive security patches:

1. **Managed Node Groups**:
   - Update the AMI ID in the terragrunt configuration
   - Apply the update to trigger a rolling update of the nodes

2. **Karpenter Nodes**:
   - Update the AMI in the Karpenter Provisioner configuration
   - Apply the update and schedule nodes for recycling

3. **Update Commands**:
   ```bash
   # Update Managed Node Groups
   cd terragrunt/us-east-1/node-groups
   terragrunt plan
   terragrunt apply
   
   # Update Karpenter Provisioner
   cd terragrunt/us-east-1/karpenter
   terragrunt plan
   terragrunt apply
   ```

### 3. Application Updates

For application updates, the GitOps workflow should be followed:

1. **Build and Tag**: CI pipeline builds and tags a new container image
2. **Push to ECR**: Image is pushed to ECR and scanned for vulnerabilities
3. **Update Helm Chart**: Update the image tag in the Helm chart values
4. **Commit to Git**: Push changes to the Git repository
5. **Argo CD Sync**: Argo CD detects the changes and applies them

### 4. Dependency Updates

Dependencies should be regularly updated:

1. **Python Dependencies**:
   - Update `requirements.txt` with new versions
   - Run tests to ensure compatibility
   - Rebuild and deploy the container image

2. **Helm Charts**:
   - Update chart versions in the Helm chart `Chart.yaml` files
   - Test updates in a staging environment before production

## Regular Security Tasks

1. **Vulnerability Scanning**: Review Trivy reports weekly
2. **Policy Compliance**: Review Polaris audit reports weekly
3. **Secret Rotation**: Rotate service account credentials quarterly
4. **Network Policy Review**: Review and update network policies quarterly
5. **Updates Assessment**: Evaluate available updates monthly

## Disaster Recovery

1. **Backup Strategy**:
   - EBS snapshots for persistent volumes
   - ECR image replication across regions
   - Git repository backup
   - AWS Secrets Manager cross-region replication

2. **Recovery Procedure**:
   - Restore EBS volumes from snapshots
   - Deploy infrastructure in backup region
   - Update DNS to point to the backup region

## Security Contacts

- **Security Team**: security@example.com
- **AWS Support**: Through AWS Support Center
- **Emergency Contact**: 555-123-4567