# Architecture Diagram Description

## Overview for Image Generation

This document provides detailed specifications for generating an architecture diagram of the Multi-Region AWS EKS Infrastructure. The diagram should visualize a comprehensive Kubernetes deployment across two AWS regions with all major components clearly defined.

## Core Architecture Components

### Multi-Region Layout (Two-Column Design)

Create a diagram with two identical architectures side by side, clearly labeled:
- Left side: **US East (N. Virginia)** / `us-east-1`
- Right side: **US West (Oregon)** / `us-west-2`
- Show a thin connecting line between regions labeled "Cross-Region Replication"

### Per-Region Components 

For each region, display the following nested structure (from outside to inside):

1. **AWS Region Boundary** (Rounded rectangle containing everything in the region)
   
2. **VPC** (Clearly labeled rectangle inside the region)
   - VPC CIDR: `10.10.0.0/16` (us-east-1) and `10.20.0.0/16` (us-west-2)
   
3. **Availability Zones** (3 vertical columns inside each VPC)
   - Label as "AZ-1a", "AZ-1b", "AZ-1c" (for us-east-1)
   - Label as "AZ-2a", "AZ-2b", "AZ-2c" (for us-west-2)

4. **Subnets** (Inside each AZ, show two rectangles stacked vertically)
   - Public subnet at the top of each AZ (labeled with CIDR)
   - Private subnet at the bottom of each AZ (labeled with CIDR)
   
5. **NAT Gateways** (Small icon in each public subnet)
   - Place in the public subnet of each AZ
   - Show arrow to Internet Gateway
   
6. **Internet Gateway** (Icon at the top of the VPC)
   - Single Internet Gateway per VPC
   - Show connection to all public subnets

### EKS Cluster Details

Inside each region, draw an EKS cluster spanning all three private subnets:

1. **EKS Control Plane** (Central component at the top of private subnets)
   - Label as "EKS Control Plane (Private Endpoint)"
   - Show a KMS key icon with label "Secrets Encryption"

2. **Node Groups** (Use different colors for different node groups)
   - Show 4 distinct node groups across the private subnets:
     - **Monitoring Node Group**: t3.large (blue color)
     - **Management Node Group**: t3.medium (green color)
     - **Services Node Group**: m5.large (orange color)
     - **Data Node Group**: r5.xlarge (purple color)
   - Each node group should contain small EC2 instance icons

### Workload Components

On top of the node groups, show these key workloads (pod icons):

1. **On Management Node Group** (green background)
   - Argo CD (labeled icon)
   - Karpenter Controller (labeled icon)
   - KEDA Controller (labeled icon)
   - External Secrets Operator (labeled icon)

2. **On Monitoring Node Group** (blue background)
   - Prometheus (labeled icon)
   - Grafana (labeled icon)
   - Alertmanager (labeled icon)

3. **On Services Node Group** (orange background)
   - Python Flask Application (multiple pod icons showing horizontal scaling)
   - Fluentd DaemonSet (one icon per node)

4. **On Data Node Group** (purple background)
   - MySQL (labeled icon with EBS volume attachment)
   - Elasticsearch (3 labeled icons with EBS volume attachments)

### Networking & Ingress

1. **AWS Load Balancer Controller** (on Management Node Group)
   - Show controller icon

2. **Application Load Balancers** (above the VPC)
   - Show ALB icon with HTTPS/443 label
   - Connection to "app.blizzard.co.il" DNS name
   - Arrow pointing to Services Node Group

3. **Network Policies** (dotted lines between components)
   - Show zero-trust connections between service components

### External Services

1. **AWS Secrets Manager** (Outside the VPC)
   - Show icon connected to External Secrets Operator

2. **Amazon ECR** (Outside the VPC)
   - Container registry icon
   - Arrow to the application pods (image pull)

3. **Route 53** (At the very top, spanning both regions)
   - DNS service directing to both regions' ALBs
   - "blizzard.co.il" domain

### CI/CD Flow

Show a simplified pipeline on the left side:

1. **GitHub Repository** (Icon at the top)
2. **GitHub Actions** (Connected to GitHub)
3. **Arrow to ECR** (Image push)
4. **Arrow to Argo CD** (GitOps update)
5. **Arrow from Argo CD to application pods** (Deployment)

## Color Scheme & Style

- **Regions**: Light blue background
- **VPCs**: White background with blue border
- **Public Subnets**: Light green background
- **Private Subnets**: Light gray background
- **Node Groups**: Different pastel colors as noted above
- **Control Flow**: Blue arrows
- **Data Flow**: Green arrows
- **Security Boundaries**: Red dotted lines

## Key Elements to Emphasize

1. **Multi-Region Redundancy**: Show identical setups in both regions
2. **Workload Isolation**: Different node groups for different workloads
3. **Security**: Network policies, private endpoints, KMS encryption
4. **GitOps Flow**: From GitHub to Argo CD to applications
5. **Autoscaling**: Karpenter for nodes, KEDA for pods

## Legend

Include a legend in the bottom-right corner explaining:
- Node group types and their purposes
- Line types (control flow, data flow, security boundaries)
- Key AWS services used
- Kubernetes components

## Title and Metadata

- **Title**: "Multi-Region AWS EKS Infrastructure Architecture"
- **Subtitle**: "High-Availability Kubernetes Platform with GitOps, Autoscaling, and Security"

This detailed diagram should provide a comprehensive visual representation of the entire architecture, highlighting all major components and their relationships in a production-grade Kubernetes deployment.