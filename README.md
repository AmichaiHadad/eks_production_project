# Multi-Region AWS EKS Infrastructure & Application Project

> ⚠️ **COST WARNING**: This is a full-scale production deployment that will cost approximately $64 USD per day (~$1,900 per month) to run across both regions. Consider using a single region for development or implementing shutdown schedules for non-production environments.

## Overview

This project implements a comprehensive, production-ready Kubernetes infrastructure on AWS EKS across multiple regions (us-east-1 and us-west-2) with a focus on high availability, security, and modern DevOps practices. It demonstrates a complete infrastructure-as-code approach using Terraform, Terragrunt, and GitOps methodologies to deploy and manage a resilient, scalable application infrastructure.

## Documentation & Getting Started

This project includes comprehensive documentation to help you deploy, debug, and understand the architecture:

- **[DEPLOYMENT.md](DEPLOYMENT.md)**: Complete step-by-step deployment instructions for the entire infrastructure
- **[DEBUG.md](DEBUG.md)**: Thorough debugging guide covering every component with expected behaviors and commands
- **[SECURITY-BEST-PRACTICES.md](docs/SECURITY-BEST-PRACTICES.md)**: Security recommendations and update procedures
- **[AUTOSCALING.md](docs/AUTOSCALING.md)**: Details on Karpenter and KEDA implementation

For a visual representation of the architecture, see [diagram_description.md](diagram_description.md) which provides a detailed description of the multi-region infrastructure design.

## Key Features

- **Multi-Region Deployment**: Identical infrastructure in us-east-1 and us-west-2 for high availability and disaster recovery
- **Infrastructure as Code**: All resources defined with Terraform and Terragrunt
- **GitOps Workflow**: CI/CD with GitHub Actions and Argo CD for application deployment
- **Dynamic Autoscaling**: Karpenter for node provisioning and KEDA for pod autoscaling
- **Comprehensive Monitoring**: Prometheus, Grafana, and Alertmanager with custom dashboards
- **Security-First Design**: External Secrets Operator, Network Policies, and Security Scanning
- **Stateful Workloads**: MySQL and Elasticsearch with proper persistence and backup
- **Logging Pipeline**: Centralized logging with Fluentd and Elasticsearch

## Technology Stack

### Infrastructure & Orchestration
- **AWS EKS**: Managed Kubernetes control plane
- **Terraform/Terragrunt**: Infrastructure as code with modularity
- **VPC Networking**: Multi-AZ private/public subnets with NAT Gateways
- **AWS IAM**: Least privilege access with IRSA (IAM Roles for Service Accounts)
- **AWS KMS**: Encryption for Kubernetes secrets
- **AWS Load Balancer Controller**: For ingress management
- **Kubernetes**: Latest stable version (v1.27+)

### Continuous Delivery & GitOps
- **Argo CD**: GitOps-based continuous delivery
- **GitHub Actions**: CI/CD pipeline for building and deploying
- **Amazon ECR**: Container image registry
- **Helm**: Package management for Kubernetes

### Application Stack
- **Python Flask**: Web application backend
- **MySQL**: Relational database
- **Elasticsearch**: Search and logging
- **Fluentd**: Log collection and forwarding

### Monitoring & Observability
- **Prometheus**: Metrics collection
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert management and routing
- **Exporters**: Custom metrics collection from MySQL and Elasticsearch

### Autoscaling
- **Karpenter**: Just-in-time node provisioning
- **KEDA**: Event-driven pod autoscaling
- **Prometheus Metrics**: Used as scaling triggers

### Security
- **External Secrets Operator**: Secure secrets management with AWS Secrets Manager
- **Network Policies**: Zero-trust network model
- **Pod Security Standards**: Enforced at namespace level
- **Trivy**: Container vulnerability scanning
- **Polaris**: Kubernetes security policy validation

## Project Structure

```
/mnt/d/research/eks_project_v2/
├── app/                              # Python application code
│   ├── app.py                        # Main application file
│   ├── Dockerfile                    # Container definition
│   └── requirements.txt              # Python dependencies
├── argocd/                           # Argo CD ApplicationSets
│   ├── app-applicationset.yaml       # Application deployment
│   ├── monitoring-applicationset.yaml # Monitoring stack
│   ├── stateful-applicationset.yaml  # Stateful services
│   ├── autoscaling-applicationset.yaml # Autoscaling components
│   └── security-applicationset.yaml  # Security components
├── docs/                             # Documentation
│   ├── AUTOSCALING.md                # Autoscaling documentation
│   └── SECURITY-BEST-PRACTICES.md    # Security documentation
├── helm-chart/                       # Helm charts
│   ├── app/                          # Application Helm chart
│   ├── elasticsearch/                # Elasticsearch Helm chart
│   ├── fluentd/                      # Fluentd Helm chart
│   ├── monitoring/                   # Monitoring stack Helm chart
│   ├── mysql/                        # MySQL Helm chart
│   ├── autoscaling/                  # Autoscaling Helm chart
│   └── security/                     # Security Helm chart
├── terraform/                        # Terraform modules
│   ├── modules/
│   │   ├── argocd/                   # Argo CD module
│   │   ├── eks-cluster/              # EKS cluster module
│   │   ├── external-secrets/         # External Secrets module
│   │   ├── karpenter/                # Karpenter module
│   │   ├── keda/                     # KEDA module
│   │   ├── network-policies/         # Network Policies module
│   │   ├── node-groups/              # EKS node groups module
│   │   ├── security-policies/        # Security Policies module
│   │   └── vpc/                      # VPC networking module
├── terragrunt/                       # Terragrunt configurations
│   ├── terragrunt.hcl                # Root Terragrunt config
│   ├── us-east-1/                    # us-east-1 region config
│   │   ├── region.hcl                # Region-specific variables
│   │   ├── networking/               # VPC configuration
│   │   ├── eks/                      # EKS cluster configuration
│   │   ├── node-groups/              # Node groups configuration
│   │   ├── argocd/                   # Argo CD configuration
│   │   ├── karpenter/                # Karpenter configuration
│   │   ├── keda/                     # KEDA configuration
│   │   ├── external-secrets/         # External Secrets configuration
│   │   ├── network-policies/         # Network Policies configuration
│   │   └── security-policies/        # Security Policies configuration
│   └── us-west-2/                    # us-west-2 region config
│       ├── region.hcl                # Region-specific variables
│       ├── networking/               # VPC configuration
│       ├── eks/                      # EKS cluster configuration
│       ├── node-groups/              # Node groups configuration
│       ├── argocd/                   # Argo CD configuration
│       ├── karpenter/                # Karpenter configuration
│       ├── keda/                     # KEDA configuration
│       ├── external-secrets/         # External Secrets configuration
│       ├── network-policies/         # Network Policies configuration
│       └── security-policies/        # Security Policies configuration
├── testing/                          # Testing scripts
│   ├── load-test.yaml                # Load testing configuration
│   └── security-tests.sh             # Security testing script
├── .gitignore                        # Git ignore file for project
├── ClaudeProgress.MD                 # Implementation progress tracker
├── DEBUG.md                          # Comprehensive debugging guide for all components
├── DEPLOYMENT.md                     # Step-by-step deployment instructions
├── Project_Master_Definition.md      # Original project requirements
├── README.md                         # This file
└── diagram_description.md            # Detailed architecture diagram description
```

## Architecture Design

### Network Architecture

The project implements a multi-region architecture with two identical EKS clusters:

- **VPC Design**:
  - us-east-1: CIDR 10.10.0.0/16
  - us-west-2: CIDR 10.20.0.0/16
  - Each VPC has 3 private subnets and 3 public subnets across different AZs
  - NAT Gateways in each public subnet for outbound connectivity
  - Internet Gateway for public subnet access

- **EKS Configuration**:
  - Private API endpoint access only (no public endpoint exposure)
  - KMS encryption for Kubernetes secrets
  - CloudWatch logging for audit, API, authenticator logs

### Compute Architecture

Workloads are isolated across specialized node groups:

- **Monitoring Node Group**: t3.large instances for Prometheus, Grafana
- **Management Node Group**: t3.medium instances for Argo CD and controllers
- **Services Node Group**: m5.large instances for application workloads
- **Data Node Group**: r5.xlarge instances for MySQL and Elasticsearch

Dynamic scaling is implemented using:
- **Karpenter**: For just-in-time node provisioning
- **KEDA**: For application scaling based on custom metrics

### Application Architecture

The Python Flask application demonstrates key microservice patterns:

- **Stateless Design**: Horizontal scaling with multiple replicas
- **External Configuration**: Environment variables and ConfigMaps
- **Secret Management**: External Secrets Operator integration
- **Health Checks**: Liveness and readiness probes
- **Metrics Exposure**: Prometheus integration
- **Database Integration**: MySQL for data persistence
- **Logging**: Structured logging to Elasticsearch via Fluentd

### Security Architecture

Security is implemented following defense-in-depth principles:

- **Network Security**:
  - Zero-trust network model with default deny policies
  - Specific ingress/egress rules for required communication
  - Private EKS API endpoint

- **Secret Management**:
  - AWS Secrets Manager integration via External Secrets Operator
  - KMS encryption for Kubernetes secrets

- **Pod Security**:
  - Restricted pod security standard enforcement
  - Non-root container execution
  - Read-only root filesystem
  - Dropped capabilities

- **Continuous Security**:
  - Trivy for vulnerability scanning
  - Polaris for Kubernetes best practices
  - Image scanning in ECR

## Why This Design

### Multi-Region Strategy

The multi-region design provides several key benefits:

1. **High Availability**: Services remain available even if an entire AWS region experiences an outage
2. **Disaster Recovery**: Data and infrastructure can be recovered from the secondary region
3. **Geographic Distribution**: Lower latency for users in different regions
4. **Regulatory Compliance**: Helps meet data residency requirements in different regions

### Specialized Node Groups

The dedicated node groups for different workloads enable:

1. **Resource Efficiency**: Rightsizing instances for specific workload requirements
2. **Isolation**: Preventing noisy neighbor problems between workloads
3. **Scaling Independence**: Different scaling policies for different workload types
4. **Billing Separation**: Clearer cost attribution for different components

### GitOps Workflow

The GitOps approach provides:

1. **Declarative Configuration**: All desired states are defined in Git
2. **Auditability**: Complete history of all changes
3. **Automation**: Continuous deployment from Git source
4. **Consistency**: Identical deployments across environments
5. **Rollback Capability**: Easy reversions to previous states

### Kubernetes Native Autoscaling

The Karpenter and KEDA combination delivers:

1. **Rapid Scaling**: Just-in-time provisioning of nodes
2. **Cost Optimization**: Nodes are added only when needed
3. **Event-Driven Scaling**: Scale based on any metric or event
4. **Customizable Policies**: Fine-grained control over scaling decisions

### Comprehensive Monitoring

The monitoring stack provides:

1. **Full Visibility**: Metrics from all components of the system
2. **Custom Dashboards**: Specialized views for different stakeholders
3. **Proactive Alerting**: Early warning of potential issues
4. **Historical Analysis**: Trend analysis and capacity planning

## Use Cases

This infrastructure is designed to support various enterprise use cases:

1. **Web Applications**: Horizontally scalable web services with database backend
2. **API Services**: RESTful or GraphQL APIs with authentication and monitoring
3. **Data Processing**: Batch or stream processing with autoscaling
4. **DevOps Platforms**: CI/CD pipelines and automation tools
5. **Logging & Analytics**: Centralized logging and real-time data analysis

## Future Enhancements

Potential enhancements for this project include:

1. **Global Database**: Aurora Global Database for cross-region data replication
2. **Service Mesh**: Istio or AWS App Mesh for advanced traffic management
3. **Serverless Integration**: AWS Lambda integration for event handling
4. **Advanced CI/CD**: Promotion workflows across multiple environments
5. **Cost Optimization**: Spot instance usage for non-critical workloads
6. **Compliance Automation**: Automated security scanning and compliance reporting

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

This project was inspired by AWS EKS best practices and the Kubernetes community's recommended patterns for production deployments.

---

*Note: This project is designed for educational and demonstration purposes. For production use, additional security hardening and compliance testing should be performed.*