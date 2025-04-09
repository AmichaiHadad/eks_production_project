# Items Removed/Disabled from `security-policies` Module

This file tracks components and configurations that were removed or disabled from the `terraform/modules/security-policies` module during troubleshooting. These items might need to be re-added or configured differently later in the deployment process, potentially via Helm charts managed by ArgoCD.

1.  **Trivy Operator RBAC/SA (`kubectl_manifest.trivy_operator`)**
    *   **Status:** Removed from `main.tf` and `templates/trivy-operator.yaml`.
    *   **Reason:** To avoid conflict with the Trivy Operator deployment managed by the `helm-chart/security` Helm chart and deployed via `argocd/security-applicationset.yaml`. The Helm chart should manage all Trivy Operator resources.

2.  **Trivy VulnerabilityReport Configuration (`kubectl_manifest.vulnerability_scanning_config`)**
    *   **Status:** Removed from `main.tf` and `templates/vulnerability-scan.yaml`.
    *   **Reason:** This resource requires the Trivy Operator's CRDs to be present. Its configuration should likely be part of the Trivy Operator's Helm values or applied after the operator is confirmed running.

3.  **Kubernetes Audit Policy (`kubectl_manifest.security_audit_policy`)**
    *   **Status:** Removed from `main.tf` and `templates/audit-policy.yaml`.
    *   **Reason:** Kubernetes Audit Policy objects (`audit.k8s.io/v1/Policy`) cannot be applied directly via `kubectl` or `kubectl_manifest`. Audit logging configuration is managed at the EKS cluster level (currently enabled to CloudWatch via the `eks-cluster` module). Specific policy *files* need to be referenced during cluster creation/updates if customizing beyond basic log types.

4.  **ECR Scan Policy ConfigMap (`kubectl_manifest.ecr_image_scanner_policy`)**
    *   **Status:** Removed from `main.tf` and `templates/ecr-scan-policy.yaml`.
    *   **Reason:** The purpose and consumer of this ConfigMap were unclear. ECR scan-on-push is already configured via AWS CLI in `DEPLOYMENT.md`, making this ConfigMap potentially redundant. Needs verification if any component actually uses it.

5.  **Polaris Audit Component (`helm_release.polaris` -> `audit.enable`)**
    *   **Status:** Disabled via `audit.enable: false` in `templates/polaris-values.yaml`.
    *   **Reason:** Caused Helm template errors (`nil pointer evaluating interface {}.configUrl`). Can be re-evaluated and potentially re-enabled if the configuration issue is resolved or if external reporting is needed.

6.  **Polaris Webhook Component (`helm_release.polaris` -> `webhook.enable`)**
    *   **Status:** Disabled via `webhook.enable: false` in `templates/polaris-values.yaml`.
    *   **Reason:** Bypassed Helm template errors related to `cert-manager` dependencies (`Certificate` and `Issuer` resources). The webhook provides admission control based on Polaris checks, which is a valuable security feature. Consider re-enabling this later, possibly by installing `cert-manager` or investigating the chart's options for self-signed certificates if available. 