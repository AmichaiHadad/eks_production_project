# Project Cleanup Guide

This guide provides instructions to completely remove all AWS resources and configurations created by the EKS Production Project deployment across all configured regions (e.g., `us-east-1` and `us-west-2`).

**Warning:** Following these steps will permanently delete your infrastructure, including EKS clusters, databases (MySQL, Elasticsearch), logs, monitoring data, and application data. Ensure you have backed up anything important before proceeding.

## Step 1: Destroy Infrastructure with Terragrunt

The primary method for removing infrastructure managed by Terraform/Terragrunt is using the `destroy` command.

1.  **Navigate to the Terragrunt Root:**
    Open your terminal and change to the root directory where your top-level `terragrunt` configuration resides (the directory containing the `us-east-1` and `us-west-2` subdirectories).
    ```bash
    cd path/to/your/eks_production_project/terragrunt
    ```

2.  **Run `run-all destroy`:**
    Execute the following command. Terragrunt will determine the reverse order of dependencies and destroy resources across **all** configured regions.
    ```bash
    terragrunt run-all destroy
    ```

3.  **Confirm Destruction:**
    Terragrunt will show a plan of resources to be destroyed for each module in each region. Carefully review the plan.
    *   You will be prompted multiple times (once for each module per region) to confirm the destruction.
    *   Type `yes` at each prompt to proceed.

    **Important:** This process will take a significant amount of time, potentially as long as the deployment, as Terragrunt waits for resources to terminate.

4.  **Monitor Output:**
    Watch the output for any errors. Occasionally, dependencies or timing issues might cause a resource deletion to fail. If errors occur, you may need to re-run the `terragrunt run-all destroy` command or proceed to manual cleanup for the failed resources.

## Step 2: Manual Verification and Cleanup

After `terragrunt run-all destroy` completes (even if successfully), it's crucial to manually verify resource deletion in the AWS Management Console or using the AWS CLI for **both** regions (`us-east-1` and `us-west-2`). Some resources might persist or require explicit manual deletion.

**Check the following in both `us-east-1` and `us-west-2`:**

1.  **ECR Repositories:**
    *   **Why:** These are often created outside the main Terraform/Terragrunt lifecycle (e.g., manually or via separate scripts) and might not be deleted by the destroy command.
    *   **Action:** Navigate to the ECR console for each region. Find the `eks-blizzard/app` repository (or your named equivalent). Select it and choose "Delete". You might need to force delete if images are present.
        ```bash
        # Example CLI command (run for each region)
        AWS_REGION=us-east-1 # or us-west-2
        REPO_NAME="eks-blizzard/app"
        aws ecr delete-repository --repository-name ${REPO_NAME} --region ${AWS_REGION} --force
        ```

2.  **Load Balancers (ALBs/NLBs):**
    *   **Why:** Sometimes ALBs created by the AWS Load Balancer Controller might linger if the controller or its associated resources (like the Ingress) weren't cleanly deleted first.
    *   **Action:** Check the EC2 Load Balancers section in the console for each region. Delete any ALBs associated with the `argocd` or `app` ingresses if they still exist.

3.  **EBS Volumes:**
    *   **Why:** PersistentVolumeClaims (PVCs) used by StatefulSets like MySQL and Elasticsearch might have a `Retain` reclaim policy, or deletion might fail.
    *   **Action:** Check the EC2 EBS Volumes section in the console for each region. Look for volumes associated with MySQL or Elasticsearch PVCs. If they are in an `available` state (meaning the pod is gone but the volume persists), you can delete them manually. Ensure they are no longer needed.

4.  **Secrets Manager Secrets:**
    *   **Why:** The `external-secrets` Terraform module is configured to tag secrets as `inactive` on destroy, but not delete them immediately to prevent accidental data loss.
    *   **Action:** Go to the Secrets Manager console for each region. Filter secrets by the prefix used (e.g., `eks-blizzard/`). Select the secrets created by the deployment (MySQL, Grafana, Weather API, Slack) and choose "Schedule deletion". The default minimum wait period is 7 days.

5.  **KMS Keys:**
    *   **Why:** The KMS keys created for EKS secret encryption might not be deleted automatically by Terragrunt, especially if marked as potentially shared.
    *   **Action:** Go to the KMS console for each region. Find the keys with aliases `alias/eks-blizzard-us-east-1-key` and `alias/eks-blizzard-us-west-2-key` (or your equivalents). Schedule them for deletion if they are no longer needed by any other resources. Note that KMS keys also have a mandatory waiting period before deletion.

6.  **CloudWatch Log Groups:**
    *   **Why:** Log groups created by EKS or other services might persist.
    *   **Action:** Go to the CloudWatch console -> Log Groups for each region. Find log groups related to the EKS cluster (e.g., `/aws/eks/eks-blizzard-<region>/cluster`) or specific applications and delete them if desired.

**Check the following (Centrally Managed):**

7.  **S3 State Bucket:**
    *   **Why:** This bucket contains your Terraform state files and needs to be manually deleted.
    *   **Action:** Go to the S3 console. Find the bucket you created for Terragrunt state (e.g., `your-unique-prefix-tfstate`). **First, empty the bucket**, then delete it. Ensure you no longer need the state files.

8.  **DynamoDB Lock Table:**
    *   **Why:** This table handles Terraform state locking and needs manual deletion.
    *   **Action:** Go to the DynamoDB console in the region where you created the table. Find the lock table (e.g., `your-unique-prefix-tflocks`) and delete it.

## Final Check

After running `terragrunt run-all destroy` and performing manual cleanup, double-check the AWS console in both regions for any remaining resources associated with the project (e.g., EC2 instances, IAM roles/policies, security groups, VPCs) to ensure complete removal and avoid unexpected costs.