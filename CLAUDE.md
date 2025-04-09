# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Lint/Test Commands
- Setup: `terraform init && terragrunt init`
- Plan Infrastructure: `terragrunt plan-all`
- Apply Infrastructure: `terragrunt apply-all`
- Lint Terraform: `terraform fmt -recursive`
- Validate Terraform: `terraform validate`
- Linting Python: `flake8 app/`
- Run Tests: `pytest app/tests/`
- Single Test: `pytest app/tests/test_file.py::test_function`
- Helm Lint: `helm lint helm-chart/`
- Format Python: `black app/`

## Code Style Guidelines
- Use Terraform 1.11+ and AWS provider ~v5.x
- Organize Terraform into reusable modules (vpc, eks-cluster, node_groups)
- Use Terragrunt for DRY configuration and state isolation
- Region-specific values belong in Terragrunt config files 
- Maintain separate state files for network, cluster, apps components
- Use nodeSelector/tolerations for workload segregation on node groups
- Store ALL secrets using External Secrets Operator, not in Git
- Use IAM Roles for Service Accounts (IRSA) for pod AWS API access
- Python apps should use environment variables for configuration
- Implement GitOps workflow with Argo CD for deployments
- Tag Docker images with git SHA or semantic version
- Use namespaces to isolate workloads (app, monitoring, data, etc.)
- Document alert rules and runbook procedures