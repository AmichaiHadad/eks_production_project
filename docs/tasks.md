# Dynamic Secret Name Propagation Strategy

**Status:** ✅ Completed

This document outlines the steps required to ensure dynamically generated AWS Secrets Manager secret names (including the random suffix) are consistently propagated throughout the EKS Blizzard project, from Terraform/Terragrunt to Argo CD ApplicationSets and finally to Helm charts, eliminating hardcoded secret names in Helm templates.

**Goal:** Ensure that `ExternalSecret` resources always reference the exact, dynamically generated AWS Secrets Manager secret name created by Terraform, using a parameter-passing mechanism rather than hardcoding the base name.

**Current State (Post-Completion):**
*   The `terraform/modules/external-secrets` module creates AWS Secrets Manager secrets with a random 6-character suffix (e.g., `eks-blizzard/mysql-app-user-abcdef`) and outputs the full names.
*   The `terragrunt/us-east-1/argocd` module passes these full names as parameters to the Argo CD ApplicationSet definitions.
*   The `argocd/app-applicationset.yaml` and `argocd/stateful-applicationset.yaml` files receive these parameters and inject them into the respective Helm chart invocations.
*   The `app`, `mysql`, and `monitoring` Helm charts use these injected parameters in their `ExternalSecret` templates (`remoteRef.key` or `dataFrom.extract.key`) to reference the correct, dynamically named AWS secrets.

**Required Changes (Completed):**

**(Ordered by Dependency)**

### 1. Verify Terraform Module Outputs (`terraform/modules/external-secrets`)

*   **Action:** Confirm that `outputs.tf` accurately outputs the *full* AWS Secrets Manager names (including the random suffix generated in `main.tf`) for all relevant secrets.
*   **Secrets Verified:**
    *   `mysql_app_user_secret_name` 
    *   `weather_api_secret_name` 
    *   `slack_webhook_secret_name` 
    *   `grafana_admin_secret_name` 
*   **Status:** ✅ Completed

### 2. Update Terragrunt Argo CD Configuration (`terragrunt/us-east-1/argocd/terragrunt.hcl`)

*   **Action:** Modify the `inputs` block to pass the necessary secret name outputs from the `external-secrets` dependency to the `app` and `stateful-services` (specifically for MySQL) ApplicationSets.
*   **Details:** Correct parameters (`weather_api_aws_secret_name`, `mysql_app_user_aws_secret_name`, etc.) added to `inputs.application_sets` list definitions, referencing `dependency.external_secrets.outputs`.
*   **Status:** ✅ Completed

### 3. Update Argo CD ApplicationSet Definitions (`argocd/`)

*   **Action:** Modify the `ApplicationSet` definitions to *receive* the parameters passed from Terragrunt and pass them down as Helm parameters.
*   **Files:**
    *   `argocd/app-applicationset.yaml`: Updated `helm.parameters` to receive AWS secret names (e.g., `{{ weather_api_aws_secret_name }}`).
    *   `argocd/stateful-applicationset.yaml`: Updated `helm.parameters` with conditional logic (`if eq .element.name "mysql"`) to pass the `mysql_app_user_aws_secret_name` parameter only to the MySQL chart instantiation.
    *   `argocd/monitoring-applicationset.yaml`: Verified existing parameters correctly receive values.
*   **Status:** ✅ Completed

### 4. Update Helm Charts (`helm-chart/`)

*   **Action:** Modify Helm charts to use the passed-in parameters instead of hardcoded AWS secret names in `ExternalSecret` definitions.
*   **Files:**
    *   **`helm-chart/app`**:
        *   `values.yaml`: Added `secrets.weatherAPIAwsSecretName`, `secrets.mysqlAppUserAwsSecretName`.
        *   `templates/secrets.yaml`: Updated `ExternalSecret` resources to use `{{ .Values.secrets.* }}` for `remoteRef.key` / `dataFrom.extract.key`.
    *   **`helm-chart/mysql`**:
        *   `values.yaml`: Added `secrets.mysqlAppUserAwsSecretName`.
        *   `templates/externalsecret-mysql.yaml`: Updated `ExternalSecret` `remoteRef.key` to use `{{ .Values.secrets.mysqlAppUserAwsSecretName }}`.
    *   **`helm-chart/monitoring`**:
        *   Verified `values.yaml` and `ExternalSecret` templates correctly use `slackWebhookSecretName` and `grafanaAdminSecretName`.
*   **Status:** ✅ Completed

### 5. Update Deployment Guide (`deploy-us-east.md`)

*   **Action:** Reflect the changes in the deployment steps.
*   **Details:** Step 8 (Helm Chart Values) updated to remove manual secret/ingress value setting. Step 10 (Deploy K8s Workloads) updated with a note explaining dynamic injection.
*   **Status:** ✅ Completed

### 6. Update Documentation (`docs/tasks.md`)

*   **Action:** Update this document to reflect completion.
*   **Status:** ✅ Completed

By following these steps, the project consistently uses the dynamically generated AWS Secrets Manager names across all components, enhancing security and reducing the risk associated with hardcoded values or potential secret name collisions.

## Namespace Management Module

**Goal:** Create a dedicated Terragrunt module to manage Kubernetes namespaces required by various applications and policies, ensuring they are created before dependent resources.

**Status:** In Progress ⏳

**Steps:**

*   [x] **1. Define Task:** Document the need and plan for namespace management. (Status: Done ✅)
*   [x] **2. Create Module Structure:** Set up the directory (`terragrunt/us-east-1/namespaces`) and basic files (`terragrunt.hcl`, `main.tf`). (Status: Done ✅)
*   [x] **3. Implement Namespace Resources:** Add `kubernetes_namespace` resources for `monitoring`, `data`, `logging`, `security` in `main.tf`. (Status: Done ✅)
*   [ ] **4. Verify Dependencies:** Ensure this module runs before `network-policies` and other dependent modules in the Terragrunt execution order. (Status: Pending - Manual step during deployment)
*   [x] **5. Document Completion:** Update this task list and `docs/status.md`. (Status: Done ✅)
*   [x] **6. Provide Deployment Instructions:** Outline how to apply the new module. (Status: Done ✅)

**Target Namespaces:**

*   `monitoring`