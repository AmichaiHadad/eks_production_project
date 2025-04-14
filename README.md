# EKS Production Project

## Overview

This project demonstrates the deployment of a resilient, scalable, and observable Python web application on Amazon EKS (Elastic Kubernetes Service) across multiple AWS regions (`us-east-1` and `us-west-2`). It utilizes Infrastructure as Code (IaC) with Terraform and Terragrunt for managing AWS infrastructure and employs GitOps practices via Argo CD for deploying Kubernetes applications and services.

The setup includes:
*   Multi-region EKS clusters.
*   VPC networking with public/private subnets per region.
*   Managed Node Groups and Karpenter for efficient node management and autoscaling.
*   A sample Python (Flask) application.
*   Databases and logging services (MySQL, Elasticsearch, Fluentd).
*   A comprehensive monitoring stack (Prometheus, Grafana, Alertmanager).
*   Security tooling (Trivy Operator, Polaris, Network Policies).
*   Event-driven application autoscaling (KEDA).
*   Secure secrets management (AWS Secrets Manager, External Secrets Operator).
*   Automated DNS and Load Balancing (ExternalDNS, AWS Load Balancer Controller).
*   CI/CD pipeline using GitHub Actions for container image builds.

## Goal

The primary goal is to provide a robust and production-ready template for deploying applications on EKS, emphasizing best practices for:
*   **Infrastructure as Code:** Repeatable and version-controlled infrastructure.
*   **GitOps:** Declarative application and configuration management.
*   **Multi-Region Deployment:** High availability and regional isolation.
*   **Observability:** Integrated monitoring, logging, and alerting.
*   **Scalability & Resilience:** Automated node and application scaling.
*   **Security:** Secure secrets handling, network policies, and vulnerability scanning.

## Core Technologies

*   **Cloud Provider:** AWS (EKS, VPC, EC2, ALB, Route 53, S3, Secrets Manager, KMS, IAM, ECR)
*   **IaC:** Terraform, Terragrunt
*   **Container Orchestration:** Kubernetes (Amazon EKS)
*   **GitOps:** Argo CD
*   **CI/CD:** GitHub Actions
*   **Packaging:** Helm, Docker
*   **Monitoring:** Prometheus, Grafana, Alertmanager
*   **Logging:** Elasticsearch, Fluentd
*   **Security:** Trivy Operator, Polaris, Network Policies, AWS IAM/IRSA, External Secrets Operator
*   **Autoscaling:** Karpenter (Nodes), KEDA (Application)
*   **Networking:** AWS Load Balancer Controller, ExternalDNS
*   **Application:** Python (Flask)

## 💸💸💸 Cost Warning 💸💸💸

**Deploying this project will provision a significant amount of AWS resources in *each* target region (`us-east-1` and `us-west-2`), incurring potentially substantial costs.**

*   **Rough Daily Estimate:** **$70 - $100+ USD** (across both regions)
*   **Rough Monthly Estimate:** **$2100 - $3000+ USD** (across both regions)

Actual costs depend heavily on usage, scaling, data transfer, and regional pricing. **Use the AWS Pricing Calculator and monitor your costs closely.**

**Remember to destroy the infrastructure in *both regions* using `terragrunt run-all destroy` when not actively using it to avoid ongoing charges.**

## Technical Documentation

Detailed information about the specific modules and configurations can be found here:

*   **Terraform Modules:** [`docs/terraform.md`](./docs/terraform.md)
*   **Argo CD ApplicationSets & Helm Charts:** [`docs/argocd_modules.md`](./docs/argocd_modules.md)

## Deployment Instructions

For prerequisites, step-by-step deployment instructions, validation checks, and cleanup procedures, please refer to the comprehensive deployment guide:

*   **Deployment Guide:** [`docs/DEPLOYMENT.md`](./docs/DEPLOYMENT.md)

## Cleanup

To completely remove all resources created by this project and avoid ongoing AWS charges, follow the detailed instructions in the cleanup guide:

*   **Cleanup Guide:** [`docs/CLEANUP.md`](./docs/CLEANUP.md)