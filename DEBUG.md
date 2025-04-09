# Comprehensive Debugging Guide

This guide provides detailed procedures for debugging every component in the Multi-Region AWS EKS Infrastructure. It includes expected behaviors, rational running times, debugging commands, and what information they provide for each case.

## Table of Contents

1. [Infrastructure Components](#infrastructure-components)
   - [VPC and Networking](#vpc-and-networking)
   - [EKS Cluster](#eks-cluster)
   - [Node Groups](#node-groups)
   - [IAM Roles and Permissions](#iam-roles-and-permissions)

2. [Application Components](#application-components)
   - [Python Flask Application](#python-flask-application)
   - [MySQL Database](#mysql-database)
   - [Elasticsearch](#elasticsearch)
   - [Fluentd Logging](#fluentd-logging)

3. [GitOps Components](#gitops-components)
   - [Argo CD](#argo-cd)
   - [ApplicationSets](#applicationsets)
   - [Helm Charts](#helm-charts)

4. [Monitoring Components](#monitoring-components)
   - [Prometheus](#prometheus)
   - [Grafana](#grafana)
   - [Alertmanager](#alertmanager)

5. [Autoscaling Components](#autoscaling-components)
   - [Karpenter](#karpenter)
   - [KEDA](#keda)

6. [Security Components](#security-components)
   - [Network Policies](#network-policies)
   - [External Secrets](#external-secrets)
   - [Pod Security Standards](#pod-security-standards)

7. [Cross-Component Debugging](#cross-component-debugging)
   - [End-to-End Request Flow](#end-to-end-request-flow)
   - [Performance Bottlenecks](#performance-bottlenecks)
   - [Resource Utilization](#resource-utilization)

8. [Common Issues and Solutions](#common-issues-and-solutions)

## Infrastructure Components

### VPC and Networking

**Expected behavior:** 
- VPC with 3 public and 3 private subnets
- NAT Gateways providing outbound internet access for private subnets
- No direct path from internet to private resources
- Expected deployment time: 5-10 minutes

**Debugging Commands:**

```bash
# Check VPC status
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-eks-blizzard-us-east-1" --region us-east-1
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-eks-blizzard-us-west-2" --region us-west-2 --profile us-west-2

# Check subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxxxxx" --region us-east-1 
# Replace vpc-xxxxxxxx with your VPC ID

# Check route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxxxxxxx" --region us-east-1

# Check NAT Gateways
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-xxxxxxxx" --region us-east-1

# Check internet gateway
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=vpc-xxxxxxxx" --region us-east-1

# Check security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-xxxxxxxx" --region us-east-1

# Verify that pods can reach internet from private subnets
kubectl run -it --rm curl --image=curlimages/curl -- curl -v https://www.google.com

# Check if pod is in private subnet by getting node info and comparing subnet
NODE=$(kubectl get pod curl -o jsonpath='{.spec.nodeName}')
aws ec2 describe-instances --filters "Name=private-dns-name,Values=$NODE" --query "Reservations[0].Instances[0].SubnetId" --region us-east-1
aws ec2 describe-subnets --subnet-ids subnet-xxxxx --region us-east-1
```

**Troubleshooting:**

1. **Route tables misconfigured**: Check that private subnet route tables have a route to NAT Gateway
2. **NAT Gateway failing**: Check NAT Gateway status and Elastic IP assignment
3. **Security group rules too restrictive**: Verify outbound rules allow internet access
4. **Missing NACL rules**: Check Network ACLs aren't blocking traffic

### EKS Cluster

**Expected behavior:**
- EKS cluster with private API endpoint
- EKS version 1.27 or higher
- Control plane running and healthy
- Expected deployment time: 10-15 minutes

**Debugging Commands:**

```bash
# Check EKS cluster status
aws eks describe-cluster --name eks-blizzard-us-east-1 --region us-east-1
aws eks describe-cluster --name eks-blizzard-us-west-2 --region us-west-2 --profile us-west-2

# Check EKS add-ons
aws eks list-addons --cluster-name eks-blizzard-us-east-1 --region us-east-1

# View cluster info
kubectl cluster-info

# Check component status
kubectl get componentstatuses

# Check control plane logs (if CloudWatch logging is enabled)
aws logs get-log-events --log-group-name /aws/eks/eks-blizzard-us-east-1/cluster --log-stream-name kube-apiserver-audit --region us-east-1 --limit 10

# Check OIDC provider
aws iam list-open-id-connect-providers --region us-east-1
```

**Troubleshooting:**

1. **Cluster creation fails**: Check CloudFormation events, verify IAM permissions
   ```bash
   aws cloudformation describe-stack-events --stack-name eksctl-eks-blizzard-us-east-1-cluster --region us-east-1
   ```

2. **Can't connect to API server**: Check if VPN/bastion host is needed for private endpoint access
3. **Add-on failures**: Check add-on status and update versions if needed
4. **OIDC provider missing**: Re-create OIDC provider for IAM role mappings to work

### Node Groups

**Expected behavior:**
- 4 distinct node groups (monitoring, management, services, data)
- Nodes running and registered with cluster
- Correct node labels and taints applied
- Expected deployment time: 5-10 minutes per node group

**Debugging Commands:**

```bash
# Check node group status
aws eks list-nodegroups --cluster-name eks-blizzard-us-east-1 --region us-east-1

# Get detailed node group info
aws eks describe-nodegroup --cluster-name eks-blizzard-us-east-1 --nodegroup-name eks-blizzard-us-east-1-monitoring --region us-east-1

# Check ASG status
aws autoscaling describe-auto-scaling-groups --filters "Name=tag:eks:nodegroup-name,Values=eks-blizzard-us-east-1-monitoring" --region us-east-1

# Check node status, labels, and taints
kubectl get nodes --show-labels
kubectl describe nodes | grep -A5 Taints

# Check nodes by label
kubectl get nodes -l node-role=monitoring
kubectl get nodes -l node-role=management
kubectl get nodes -l node-role=services
kubectl get nodes -l node-role=data

# Get node resource usage
kubectl top nodes

# Check node scaling history
aws autoscaling describe-scaling-activities --auto-scaling-group-name $(aws autoscaling describe-auto-scaling-groups --filters "Name=tag:eks:nodegroup-name,Values=eks-blizzard-us-east-1-services" --query "AutoScalingGroups[0].AutoScalingGroupName" --output text --region us-east-1) --region us-east-1
```

**Troubleshooting:**

1. **Nodes not joining cluster**: Check aws-auth ConfigMap
   ```bash
   kubectl get configmap aws-auth -n kube-system -o yaml
   ```

2. **Nodes stuck in NotReady**: Check kubelet logs
   ```bash
   # Get instance ID
   INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=private-dns-name,Values=ip-10-10-1-100.ec2.internal" --query "Reservations[0].Instances[0].InstanceId" --output text --region us-east-1)
   
   # Get console output
   aws ec2 get-console-output --instance-id $INSTANCE_ID --region us-east-1
   ```

3. **Capacity issues**: Check if ASG failed to provision instances due to quota or capacity
4. **Wrong labels/taints**: Update node group launch template or bootstrap script

### IAM Roles and Permissions

**Expected behavior:**
- Proper IAM roles created for cluster and node groups
- OIDC provider configured and working
- Service accounts with IAM roles properly annotated
- Expected status: All services can access required AWS APIs

**Debugging Commands:**

```bash
# List IAM roles
aws iam list-roles --query "Roles[?contains(RoleName, 'eks-blizzard')]" --region us-east-1

# Check specific role
aws iam get-role --role-name eks-blizzard-us-east-1-cluster-role --region us-east-1

# List role policies
aws iam list-attached-role-policies --role-name eks-blizzard-us-east-1-cluster-role --region us-east-1

# Check OIDC issuer
aws eks describe-cluster --name eks-blizzard-us-east-1 --query "cluster.identity.oidc.issuer" --output text --region us-east-1

# Check service account IAM annotations
kubectl get serviceaccounts -A -o jsonpath='{range .items[*]}{.metadata.namespace}{","}{.metadata.name}{","}{.metadata.annotations}{"\n"}{end}' | grep -i role

# Test IAM permissions from a pod
kubectl run -it --rm awscli --image=amazon/aws-cli --overrides='{"spec":{"serviceAccountName":"karpenter-controller"}}' -- aws sts get-caller-identity
```

**Troubleshooting:**

1. **Missing policies**: Attach required policies to roles
2. **OIDC trust issue**: Verify the trust relationship includes the correct OIDC provider
3. **Pod can't assume role**: Check service account annotation and OIDC provider URL
4. **Permission denied errors**: Review CloudTrail logs for access denied events
   ```bash
   aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=AccessDenied --region us-east-1
   ```

## Application Components

### Python Flask Application

**Expected behavior:**
- Application pods running in services node group
- Application responding to HTTP requests
- Metrics exposed on /metrics endpoint
- Connection established to MySQL and weather API
- Expected startup time: <30 seconds
- Expected response time: <500ms

**Debugging Commands:**

```bash
# Check pod status
kubectl get pods -l app=app -o wide

# View pod details
kubectl describe pod -l app=app

# Check pod logs
kubectl logs -l app=app

# Check if metrics endpoint is accessible
kubectl port-forward svc/app 5000:80
# In another terminal
curl localhost:5000/metrics

# Check environment variables
kubectl exec -it $(kubectl get pod -l app=app -o jsonpath='{.items[0].metadata.name}') -- env | sort

# Check application configuration
kubectl get configmap -l app=app -o yaml

# Test application functionality
kubectl exec -it $(kubectl get pod -l app=app -o jsonpath='{.items[0].metadata.name}') -- curl -v localhost:5000/

# Check resource usage
kubectl top pod -l app=app

# Check application in ingress
kubectl get ingress -l app=app
```

**Troubleshooting:**

1. **Pod crash-looping**: Check logs for Python exceptions
   ```bash
   kubectl logs -l app=app --previous
   ```

2. **Missing secrets**: Verify External Secrets is working and populated secrets
   ```bash
   kubectl get secret weather-api-secrets -o yaml
   kubectl get secret mysql-secrets -o yaml
   ```

3. **Weather API errors**: Check if API key is valid and application can reach the API
4. **High response time**: Check MySQL query performance or external API latency

### MySQL Database

**Expected behavior:**
- MySQL StatefulSet running on data node group
- Persistent volume attached and working
- MySQL accepting connections from application
- Expected startup time: 1-2 minutes
- Expected query time: <100ms

**Debugging Commands:**

```bash
# Check MySQL pod status
kubectl get pods -l app=mysql -o wide

# Verify MySQL is on data node
kubectl get pods -l app=mysql -o wide | grep -i data

# Check StatefulSet details
kubectl describe statefulset mysql

# View PersistentVolumeClaim status
kubectl get pvc -l app=mysql
kubectl describe pvc -l app=mysql

# Check pod logs
kubectl logs -l app=mysql

# Check MySQL service
kubectl get svc mysql

# Connect to MySQL pod
kubectl exec -it $(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- /bin/bash

# Check MySQL status from inside the pod
mysql -u root -p -e "SHOW STATUS; SHOW DATABASES; SHOW TABLES FROM app_db;"

# Check MySQL metrics (if exporter is deployed)
kubectl port-forward svc/mysql-exporter 9104:9104
# In another terminal
curl localhost:9104/metrics

# Test connection from application pod
kubectl exec -it $(kubectl get pod -l app=app -o jsonpath='{.items[0].metadata.name}') -- mysql -h mysql -u $(kubectl get secret mysql-secrets -o jsonpath='{.data.username}' | base64 -d) -p$(kubectl get secret mysql-secrets -o jsonpath='{.data.password}' | base64 -d) app_db -e "SELECT 1;"
```

**Troubleshooting:**

1. **Can't attach volume**: Check if EBS volume exists and if node is in the same AZ
   ```bash
   PV_NAME=$(kubectl get pvc -l app=mysql -o jsonpath='{.items[0].spec.volumeName}')
   kubectl describe pv $PV_NAME
   ```

2. **MySQL won't start**: Check MySQL error log inside the container
   ```bash
   kubectl exec -it $(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- cat /var/log/mysql/error.log
   ```

3. **Connection refused**: Check if MySQL service is correctly defined and networking is not blocked by NetworkPolicy
4. **Slow queries**: Check MySQL configuration and performance metrics

### Elasticsearch

**Expected behavior:**
- Elasticsearch StatefulSet running on data node group
- Cluster status green with all nodes joined
- Logs being successfully indexed
- Expected startup time: 2-3 minutes
- Expected query time: <500ms

**Debugging Commands:**

```bash
# Check Elasticsearch pod status
kubectl get pods -l app=elasticsearch -o wide

# Verify Elasticsearch is on data node
kubectl get pods -l app=elasticsearch -o wide | grep -i data

# Check StatefulSet details
kubectl describe statefulset elasticsearch

# View PersistentVolumeClaim status
kubectl get pvc -l app=elasticsearch
kubectl describe pvc -l app=elasticsearch

# Check pod logs
kubectl logs -l app=elasticsearch

# Check Elasticsearch service
kubectl get svc elasticsearch

# Get Elasticsearch cluster health
kubectl exec -it $(kubectl get pod -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}') -- curl -s -XGET 'localhost:9200/_cluster/health?pretty'

# List indices
kubectl exec -it $(kubectl get pod -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}') -- curl -s -XGET 'localhost:9200/_cat/indices?v'

# Check Elasticsearch metrics (if exporter is deployed)
kubectl port-forward svc/elasticsearch-exporter 9114:9114
# In another terminal
curl localhost:9114/metrics

# Test connection from application pod
kubectl exec -it $(kubectl get pod -l app=app -o jsonpath='{.items[0].metadata.name}') -- curl -s elasticsearch:9200
```

**Troubleshooting:**

1. **Cluster status is yellow/red**: Check for unassigned shards
   ```bash
   kubectl exec -it $(kubectl get pod -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}') -- curl -s -XGET 'localhost:9200/_cat/shards?v' | grep UNASSIGNED
   ```

2. **Memory issues**: Check JVM heap settings and system limits
   ```bash
   kubectl exec -it $(kubectl get pod -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}') -- curl -s -XGET 'localhost:9200/_nodes/stats?pretty'
   ```

3. **No logs showing up**: Verify Fluentd is running and configured correctly
4. **High disk usage**: Check index lifecycle management policies

### Fluentd Logging

**Expected behavior:**
- Fluentd DaemonSet running on all nodes
- Logs being collected and forwarded to Elasticsearch
- No pipeline errors or backpressure
- Expected startup time: <1 minute
- Expected log delivery: <5 seconds

**Debugging Commands:**

```bash
# Check Fluentd pod status
kubectl get pods -l app=fluentd -o wide

# Verify Fluentd is running on all nodes
kubectl get pods -l app=fluentd -o wide | wc -l
kubectl get nodes | grep -v NAME | wc -l

# Check DaemonSet details
kubectl describe daemonset fluentd

# Check pod logs
kubectl logs -l app=fluentd

# Check Fluentd configuration
kubectl get configmap -l app=fluentd -o yaml

# Check Fluentd metrics (if metrics endpoint is enabled)
kubectl port-forward $(kubectl get pod -l app=fluentd -o jsonpath='{.items[0].metadata.name}') 24231:24231
# In another terminal
curl localhost:24231/metrics

# Check if logs are making it to Elasticsearch
kubectl exec -it $(kubectl get pod -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}') -- curl -s -XGET 'localhost:9200/_cat/indices?v' | grep logs

# Generate test log
kubectl exec -it $(kubectl get pod -l app=app -o jsonpath='{.items[0].metadata.name}') -- bash -c 'for i in {1..10}; do echo "TEST LOG $i at $(date)"; done'
```

**Troubleshooting:**

1. **Not collecting logs**: Verify Fluentd has access to /var/log/containers
   ```bash
   kubectl exec -it $(kubectl get pod -l app=fluentd -o jsonpath='{.items[0].metadata.name}') -- ls -la /var/log/containers
   ```

2. **Connection issues to Elasticsearch**: Check NetworkPolicy and Elasticsearch service
3. **Buffer is growing**: Check Elasticsearch performance or increase Fluentd workers
4. **Parse errors**: Review Fluentd configuration for incorrect regex patterns

## GitOps Components

### Argo CD

**Expected behavior:**
- Argo CD running on management node group
- All controllers (application, repo-server, etc.) healthy
- Able to sync applications from Git
- Expected startup time: 1-2 minutes
- Expected sync time: <30 seconds for simple charts

**Debugging Commands:**

```bash
# Check Argo CD deployment status
kubectl get pods -n argocd -o wide

# Verify Argo CD is on management node
kubectl get pods -n argocd -o wide | grep -i management

# Check deployment details
kubectl describe deployment -n argocd argocd-server

# Check pod logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Get Argo CD service and ingress
kubectl get svc,ingress -n argocd

# Check Argo CD version
kubectl exec -it $(kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}') -n argocd -- argocd version

# Check repository connection
kubectl exec -it $(kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}') -n argocd -- argocd repo list

# Check Argo CD health
kubectl exec -it $(kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}') -n argocd -- argocd app list
```

**Troubleshooting:**

1. **Can't connect to Git repository**: Check repository credentials and network access
   ```bash
   kubectl get secret -n argocd argocd-repo-credentials -o yaml
   ```

2. **Application sync fails**: Check application events and logs
   ```bash
   kubectl describe application -n argocd <app-name>
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | grep -i <app-name>
   ```

3. **UI not accessible**: Check ingress configuration and certificate
4. **Long sync times**: Check repo-server logs for delays in Git operations or chart rendering

### ApplicationSets

**Expected behavior:**
- ApplicationSets creating and managing Applications
- Applications syncing successfully
- Generator working correctly (list/cluster/git generators)
- Expected creation time: <10 seconds per application

**Debugging Commands:**

```bash
# Check ApplicationSet status
kubectl get applicationsets -n argocd

# Check details of a specific ApplicationSet
kubectl describe applicationset -n argocd app-applicationset

# Check generated applications
kubectl get applications -n argocd -l app.kubernetes.io/instance=app-applicationset

# Check ApplicationSet controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller

# View ApplicationSet definition
kubectl get applicationset -n argocd app-applicationset -o yaml

# Check template rendering
kubectl get applicationset -n argocd app-applicationset -o jsonpath='{.spec.template}' | yq eval -P
```

**Troubleshooting:**

1. **No applications generated**: Check generator configuration and controller logs
2. **Template syntax errors**: Verify template syntax in ApplicationSet definition
3. **Applications not syncing**: Check individual application issues
4. **Generator failure**: For Git generators, check repository access

### Helm Charts

**Expected behavior:**
- Helm charts rendered correctly
- No missing values or template errors
- Resources created as expected
- Expected render time: <5 seconds per chart

**Debugging Commands:**

```bash
# List Helm releases
helm list -A

# Show details of a specific release
helm get all -n default app

# Check chart values
helm get values -n default app

# Validate chart without installing
helm template helm-chart/app

# Check a specific template
helm template helm-chart/app --show-only templates/deployment.yaml

# Debug chart rendering
helm template helm-chart/app --debug

# Check chart dependencies
helm dependency list helm-chart/app

# Verify chart version
helm show chart helm-chart/app
```

**Troubleshooting:**

1. **Chart render fails**: Check for syntax errors in templates
   ```bash
   helm lint helm-chart/app
   ```

2. **Missing values**: Verify values.yaml and any value overrides
3. **Dependency issues**: Update chart dependencies
   ```bash
   helm dependency update helm-chart/app
   ```

4. **Version compatibility**: Check Helm/Kubernetes version compatibility

## Monitoring Components

### Prometheus

**Expected behavior:**
- Prometheus running on monitoring node group
- All targets up and being scraped
- Data being stored and queryable
- Expected startup time: <2 minutes
- Expected query time: <500ms
- Expected resource usage: 1-4 CPU cores, 4-16GB RAM depending on metric volume

**Debugging Commands:**

```bash
# Check Prometheus pod status
kubectl get pods -n monitoring -l app=prometheus -o wide

# Verify Prometheus is on monitoring node
kubectl get pods -n monitoring -l app=prometheus -o wide | grep -i monitoring

# Check StatefulSet details
kubectl describe statefulset -n monitoring prometheus-server

# View PersistentVolumeClaim status
kubectl get pvc -n monitoring -l app=prometheus
kubectl describe pvc -n monitoring -l app=prometheus

# Check pod logs
kubectl logs -n monitoring -l app=prometheus

# Port-forward to Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
# Access at http://localhost:9090

# Check targets status
kubectl exec -it $(kubectl get pod -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -n monitoring -- wget -qO- http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {name: .labels.job, health: .health, lastError: .lastError}'

# Check storage usage
kubectl exec -it $(kubectl get pod -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -n monitoring -- wget -qO- http://localhost:9090/api/v1/status/tsdb | jq

# Test a simple query
kubectl exec -it $(kubectl get pod -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -n monitoring -- wget -qO- 'http://localhost:9090/api/v1/query?query=up' | jq
```

**Troubleshooting:**

1. **Targets down**: Check ServiceMonitor/PodMonitor and endpoint accessibility
   ```bash
   kubectl get servicemonitors,podmonitors -A
   kubectl describe servicemonitor -n monitoring app-metrics
   ```

2. **High storage usage**: Check retention settings and metrics cardinality
   ```bash
   kubectl get configmap -n monitoring prometheus-server-config -o yaml
   ```

3. **Query timeout**: Check for slow queries and resource limits
4. **Missing data**: Verify scrape configuration and endpoint annotations

### Grafana

**Expected behavior:**
- Grafana running on monitoring node group
- Dashboards loaded and displaying data
- Prometheus data source configured and working
- Expected startup time: <1 minute
- Expected dashboard load time: <3 seconds

**Debugging Commands:**

```bash
# Check Grafana pod status
kubectl get pods -n monitoring -l app=grafana -o wide

# Verify Grafana is on monitoring node
kubectl get pods -n monitoring -l app=grafana -o wide | grep -i monitoring

# Check deployment details
kubectl describe deployment -n monitoring grafana

# Check pod logs
kubectl logs -n monitoring -l app=grafana

# Port-forward to Grafana UI
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Access at http://localhost:3000

# Get Grafana admin password
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Check data sources
kubectl exec -it $(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}') -n monitoring -- curl -s -H "Authorization: Bearer admin:$(kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d)" http://localhost:3000/api/datasources | jq

# Check dashboards
kubectl exec -it $(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}') -n monitoring -- curl -s -H "Authorization: Bearer admin:$(kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d)" http://localhost:3000/api/search | jq
```

**Troubleshooting:**

1. **Can't connect to Prometheus**: Check data source configuration and network access
2. **Dashboards not loading**: Verify dashboard JSON is valid and variables are defined
3. **Plugins missing**: Install required plugins via Helm chart
4. **Authentication issues**: Reset admin password if needed
   ```bash
   kubectl delete secret -n monitoring grafana
   kubectl rollout restart deployment -n monitoring grafana
   ```

### Alertmanager

**Expected behavior:**
- Alertmanager running on monitoring node group
- Alert rules loaded and evaluating
- Notification channels configured and reachable
- Expected startup time: <1 minute
- Expected alert delivery: <10 seconds

**Debugging Commands:**

```bash
# Check Alertmanager pod status
kubectl get pods -n monitoring -l app=alertmanager -o wide

# Verify Alertmanager is on monitoring node
kubectl get pods -n monitoring -l app=alertmanager -o wide | grep -i monitoring

# Check StatefulSet details
kubectl describe statefulset -n monitoring alertmanager

# Check pod logs
kubectl logs -n monitoring -l app=alertmanager

# Port-forward to Alertmanager UI
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# Access at http://localhost:9093

# Check active alerts
kubectl exec -it $(kubectl get pod -n monitoring -l app=alertmanager -o jsonpath='{.items[0].metadata.name}') -n monitoring -- wget -qO- http://localhost:9093/api/v1/alerts | jq

# Check alert rules in Prometheus
kubectl exec -it $(kubectl get pod -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -n monitoring -- wget -qO- http://localhost:9090/api/v1/rules | jq

# Check Alertmanager configuration
kubectl get secret -n monitoring alertmanager-alertmanager -o jsonpath="{.data['alertmanager\.yaml']}" | base64 -d
```

**Troubleshooting:**

1. **Alert rules not evaluating**: Check PrometheusRule resources and Prometheus logs
   ```bash
   kubectl get prometheusrules -A
   kubectl describe prometheusrule -n monitoring app-alerts
   ```

2. **Notification failures**: Check receiver configuration and connectivity
3. **Alert not firing**: Verify alert rule expression is correct
4. **Duplicate alerts**: Check inhibition and grouping rules

## Autoscaling Components

### Karpenter

**Expected behavior:**
- Karpenter controller running on management node group
- Provisioner resources defined and active
- Nodes being created and terminated as needed
- Expected node provision time: 60-120 seconds
- Expected node termination time: <30 seconds

**Debugging Commands:**

```bash
# Check Karpenter controller status
kubectl get pods -n karpenter -l app.kubernetes.io/name=karpenter -o wide

# Verify Karpenter is on management node
kubectl get pods -n karpenter -l app.kubernetes.io/name=karpenter -o wide | grep -i management

# Check deployment details
kubectl describe deployment -n karpenter karpenter

# Check pod logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# Check Karpenter CRDs
kubectl get crds | grep karpenter

# Check provisioners
kubectl get provisioners
kubectl describe provisioner default

# Check nodes created by Karpenter
kubectl get nodes -l provisioning-group=karpenter

# Check Karpenter metrics
kubectl port-forward -n karpenter svc/karpenter 8000:8000
# In another terminal
curl localhost:8000/metrics | grep -i provisioner

# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:karpenter.sh/discovery,Values=eks-blizzard-us-east-1" --region us-east-1

# Test node provisioning (create dummy deployment needing resources)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      nodeSelector:
        node-role: services
      containers:
      - name: inflate
        image: public.ecr.aws/eks-distro/kubernetes/pause:3.2
        resources:
          requests:
            cpu: 1
            memory: 1Gi
EOF
kubectl scale deployment inflate --replicas=10
```

**Troubleshooting:**

1. **Can't provision nodes**: Check IAM permissions and instance type availability
   ```bash
   kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep -i error
   ```

2. **Nodes not terminating**: Check TTL settings and occupancy
3. **Wrong instance types**: Check provisioner specification and requirements
4. **API calls failing**: Verify endpoints and AWS API rate limits

### KEDA

**Expected behavior:**
- KEDA operator running on management node group
- ScaledObjects defined and active
- Workloads scaling based on metrics
- Expected scale-out time: <30 seconds
- Expected scale-in time: <60-180 seconds

**Debugging Commands:**

```bash
# Check KEDA controller status
kubectl get pods -n keda -l app=keda-operator -o wide

# Verify KEDA is on management node
kubectl get pods -n keda -l app=keda-operator -o wide | grep -i management

# Check deployment details
kubectl describe deployment -n keda keda-operator

# Check pod logs
kubectl logs -n keda -l app=keda-operator

# Check KEDA CRDs
kubectl get crds | grep keda.sh

# Check ScaledObjects
kubectl get scaledobjects -A
kubectl describe scaledobject -n default app-scaler

# Check HPA created by KEDA
kubectl get hpa -A
kubectl describe hpa -n default keda-hpa-app

# Check KEDA metrics
kubectl port-forward -n keda svc/keda-operator-metrics 8080:8080
# In another terminal
curl localhost:8080/metrics

# Test scaling (generate load)
kubectl apply -f testing/load-test.yaml

# Check scaling events
kubectl get events -n default --sort-by='.lastTimestamp' | grep -i scaled
```

**Troubleshooting:**

1. **Not scaling on metrics**: Check ScaledObject trigger configuration
   ```bash
   kubectl describe scaledobject -n default app-scaler
   ```

2. **Can't access metrics**: Verify KEDA can reach Prometheus
   ```bash
   kubectl exec -it $(kubectl get pod -n keda -l app=keda-operator -o jsonpath='{.items[0].metadata.name}') -n keda -- curl -s prometheus-server.monitoring:9090/api/v1/query?query=up
   ```

3. **Scaling too aggressively**: Adjust cooldown period or threshold
4. **Metric query errors**: Check query syntax and Prometheus data

## Security Components

### Network Policies

**Expected behavior:**
- Default deny policies active in all namespaces
- Specific allow policies for required traffic
- Traffic blocked unless explicitly allowed
- Expected application: Immediate for new connections

**Debugging Commands:**

```bash
# Check all Network Policies
kubectl get networkpolicies -A

# View specific policy details
kubectl describe networkpolicy -n default default-deny

# Check if pod can access specific service (run from source pod)
kubectl exec -it $(kubectl get pod -n default -l app=app -o jsonpath='{.items[0].metadata.name}') -n default -- curl -v --connect-timeout 5 mysql:3306

# Test blocked connectivity (should fail)
kubectl run -it --rm -n default nettest --image=nicolaka/netshoot -- curl -v --connect-timeout 5 elasticsearch:9200

# Test allowed connectivity with proper namespace and labels
kubectl run -it --rm -n default nettest --labels=app=app --image=nicolaka/netshoot -- curl -v --connect-timeout 5 elasticsearch:9200

# Test DNS resolution (should work)
kubectl run -it --rm -n default nettest --image=nicolaka/netshoot -- nslookup kubernetes.default.svc.cluster.local

# Log blocked connections in the kernel
kubectl create -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: policy-logger
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: logger
    image: ubuntu
    command: ["/bin/sh", "-c"]
    args:
    - apt-get update;
      apt-get install -y iptables tcpdump;
      iptables -t raw -I PREROUTING -j TRACE;
      iptables -t raw -I OUTPUT -j TRACE;
      sleep 3600;
    securityContext:
      privileged: true
  tolerations:
  - operator: Exists
EOF

kubectl logs -n kube-system policy-logger
```

**Troubleshooting:**

1. **Legitimate traffic blocked**: Check source/destination pod labels match policy selectors
2. **Policy not working**: Verify the network plugin supports Network Policies
3. **DNS resolution failing**: Ensure policy allows access to kube-dns
4. **Too restrictive**: Temporarily remove policy to verify if it's causing the issue
   ```bash
   kubectl delete networkpolicy -n default default-deny
   ```

### External Secrets

**Expected behavior:**
- External Secrets Operator running on management node group
- SecretStore/ClusterSecretStore defined and connected
- ExternalSecrets syncing successfully
- Expected sync time: <30 seconds for new/changed secrets

**Debugging Commands:**

```bash
# Check External Secrets controller status
kubectl get pods -n external-secrets -l app.kubernetes.io/name=external-secrets -o wide

# Verify External Secrets is on management node
kubectl get pods -n external-secrets -l app.kubernetes.io/name=external-secrets -o wide | grep -i management

# Check deployment details
kubectl describe deployment -n external-secrets external-secrets

# Check pod logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets

# Check External Secrets CRDs
kubectl get crds | grep external-secrets.io

# Check SecretStores
kubectl get secretstores,clustersecretstores -A
kubectl describe clustersecretstore aws-secretsmanager

# Check ExternalSecrets
kubectl get externalsecrets -A
kubectl describe externalsecret -n default mysql-secrets

# Check Kubernetes Secrets created by External Secrets
kubectl get secrets -n default mysql-secrets
kubectl get secrets -n default weather-api-secrets

# Check sync status
kubectl get externalsecrets -A -o jsonpath='{range .items[*]}{.metadata.namespace}{","}{.metadata.name}{","}{.status.conditions[?(@.type=="Ready")].status}{","}{.status.conditions[?(@.type=="Ready")].message}{"\n"}{end}'

# Test IAM role assumption
kubectl exec -it $(kubectl get pod -n external-secrets -l app.kubernetes.io/name=external-secrets -o jsonpath='{.items[0].metadata.name}') -n external-secrets -- aws sts get-caller-identity

# Check if secret exists in AWS Secrets Manager
aws secretsmanager list-secrets --region us-east-1 | jq '.SecretList[] | select(.Name | contains("eks-blizzard"))'
```

**Troubleshooting:**

1. **Can't access AWS Secrets Manager**: Check IAM permissions and network access
   ```bash
   kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets | grep -i error
   ```

2. **Secret not syncing**: Verify ExternalSecret configuration matches AWS secret
3. **Access denied**: Check IRSA setup and service account annotation
4. **Wrong data format**: Check AWS secret format and ExternalSecret property mapping

### Pod Security Standards

**Expected behavior:**
- Pod Security Standards enforced at namespace level
- Restricted profile preventing privileged pods
- No pods with host namespace access
- Expected application: Immediate for new pods

**Debugging Commands:**

```bash
# Check namespace labels for PSS enforcement
kubectl get ns -L pod-security.kubernetes.io/enforce

# Try to create a privileged pod (should fail)
kubectl run -n default priv-test --image=ubuntu --privileged -- sleep 3600

# Check events for policy violations
kubectl get events -n default | grep -i pod-security

# Check pod security context
kubectl get pods -n default -l app=app -o jsonpath='{.items[0].spec.securityContext}'

# Check container security context
kubectl get pods -n default -l app=app -o jsonpath='{.items[0].spec.containers[0].securityContext}'

# Verify security context constraints with Polaris
helm template helm-chart/app | kubectl auth-scan -f - -v

# Run security audit
kubectl run -n security policy-check --image=aquasec/kube-bench -- --benchmark cis-1.6
kubectl logs -n security policy-check
```

**Troubleshooting:**

1. **Pod creation fails**: Check security context and pod security standards
   ```bash
   kubectl describe pod -n default <pod-name>
   ```

2. **Too restrictive policy**: Consider namespace exemptions for system components
3. **Policy not enforced**: Ensure admission controller is enabled in API server
4. **Container crashing due to restrictions**: Adjust security context to minimum required

## Cross-Component Debugging

### End-to-End Request Flow

**Expected behavior:**
- Request flows from ALB → App → MySQL/Elasticsearch
- All components communicating correctly
- Full request processing in <500ms
- Logs and metrics captured at each stage

**Debugging Commands:**

```bash
# Create a test client pod
kubectl run -it --rm -n default client --image=nicolaka/netshoot -- bash

# Make a request to the application service
curl -v http://app:80/

# Check application logs for the request
kubectl logs -n default -l app=app --tail=20

# Look for MySQL query in app logs
kubectl logs -n default -l app=app | grep -i sql

# Check Elasticsearch for the logged event
kubectl exec -it $(kubectl get pod -n default -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}') -n default -- curl -s 'localhost:9200/_search?q=client_ip:*' | jq

# Check request metrics in Prometheus
kubectl exec -it $(kubectl get pod -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -n monitoring -- wget -qO- 'http://localhost:9090/api/v1/query?query=http_requests_total' | jq

# Check Ingress/ALB access logs
aws logs tail /aws/elasticloadbalancing/$ALB_NAME --region us-east-1

# Generate load and watch the flow
kubectl apply -f testing/load-test.yaml
```

**Troubleshooting:**

1. **Request fails at ALB**: Check ALB health checks and security groups
2. **App can't reach MySQL**: Verify network policy and MySQL service
3. **Logs not appearing in Elasticsearch**: Check Fluentd configuration
4. **High latency**: Use distributed tracing or logs to pinpoint bottleneck

### Performance Bottlenecks

**Expected behavior:**
- Application response time <500ms
- MySQL query time <100ms
- Elasticsearch query time <200ms
- CPU/Memory usage within limits

**Debugging Commands:**

```bash
# Check overall cluster resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods -A

# Get detailed node metrics
kubectl describe node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') | grep -A 10 Allocated

# Get application response time
time curl -s http://$(kubectl get ingress -l app=app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')/ > /dev/null

# Check MySQL slow query log
kubectl exec -it $(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- mysql -e "SHOW VARIABLES LIKE 'slow_query%';"
kubectl exec -it $(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- cat /var/log/mysql/mysql-slow.log

# Check Elasticsearch hot threads
kubectl exec -it $(kubectl get pod -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:9200/_nodes/hot_threads

# Get network metrics
kubectl top pod --containers=true -A
```

**Troubleshooting:**

1. **High CPU usage**: Check for inefficient code or resource limits
2. **Memory leaks**: Monitor memory usage over time
3. **Slow database queries**: Add indexes or optimize queries
4. **Network latency**: Check cross-AZ communication or network policies

### Resource Utilization

**Expected behavior:**
- Resource usage within request/limit ranges
- No persistent OOM events or throttling
- Smooth autoscaling as load increases
- Expected CPU usage: 40-80% of requests under load

**Debugging Commands:**

```bash
# Check resource requests and limits
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU_REQUEST:.spec.containers[0].resources.requests.cpu,CPU_LIMIT:.spec.containers[0].resources.limits.cpu,MEM_REQUEST:.spec.containers[0].resources.requests.memory,MEM_LIMIT:.spec.containers[0].resources.limits.memory

# Check node capacity and allocatable resources
kubectl describe nodes | grep -A 7 Capacity

# Find pods with highest resource usage
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Check for OOM events
kubectl get events -A | grep -i "OOMKilled"

# Check for CPU throttling
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{": "}{.status.containerStatuses[0].name}{" - CPU throttled: "}{.status.containerStatuses[0].state.waiting.reason}{"\n"}{end}' | grep "CPU throttled"

# Monitor resource usage over time (requires metrics-server)
kubectl top pods -n default -l app=app --watch

# Check autoscaling behavior
kubectl get hpa -A --watch
```

**Troubleshooting:**

1. **OOMKilled pods**: Increase memory limits or optimize application
2. **CPU throttling**: Increase CPU limits or optimize code
3. **Resource fragmentation**: Check for pod/node anti-affinity rules
4. **Unbalanced nodes**: Drain and rebalance node load if needed

## Common Issues and Solutions

### Cluster Deployment Issues

| Issue | Debugging Command | Solution |
|-------|-------------------|----------|
| IAM permissions insufficient | `aws sts decode-authorization-message --encoded-message <message>` | Add missing IAM permissions to the deploying role |
| Service quota limits | `aws service-quotas get-service-quota --service-code eks --quota-code L-1194D53C` | Request quota increase or use different instance types |
| VPC/subnet misconfiguration | `aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxxxxx"` | Ensure subnets have proper routings and are in multiple AZs |
| Terraform state corruption | `terraform state list` | Recreate state or terraform import resources back to state |

### Application Issues

| Issue | Debugging Command | Solution |
|-------|-------------------|----------|
| Pod crash-looping | `kubectl describe pod <pod-name>; kubectl logs <pod-name> --previous` | Check logs for exceptions and fix application code or configuration |
| Service not reachable | `kubectl run -it --rm nettest --image=nicolaka/netshoot -- curl -v svc-name:port` | Verify service selectors match pod labels |
| Persistent volume issues | `kubectl describe pv <pv-name>` | Check if volume exists in AWS and is in the same AZ as the node |
| Secret/ConfigMap not mounted | `kubectl describe pod <pod-name>` | Verify secret exists and volume mount is correctly defined |

### Networking Issues

| Issue | Debugging Command | Solution |
|-------|-------------------|----------|
| DNS resolution fails | `kubectl run -it --rm nettest --image=busybox -- nslookup kubernetes.default` | Check CoreDNS pods and NetworkPolicy allowing access |
| Ingress not working | `kubectl describe ingress <name>` | Verify ALB controller is running and annotations are correct |
| Network policy blocking legitimate traffic | `kubectl describe networkpolicy <name>` | Update selectors or add exceptions to allow required traffic |
| Cross-cluster connectivity | `kubectl run -it --rm nettest --image=nicolaka/netshoot -- traceroute <endpoint>` | Check VPC peering, Transit Gateway, or VPN setup |

### Autoscaling Issues

| Issue | Debugging Command | Solution |
|-------|-------------------|----------|
| Karpenter not provisioning nodes | `kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter` | Check IAM permissions and EC2 instance availability |
| KEDA not scaling pods | `kubectl describe scaledobject <name>` | Verify trigger metrics are available and correctly configured |
| HPA not getting metrics | `kubectl describe hpa <name>` | Check metrics-server is running and metrics are being collected |
| Node shortage | `kubectl get pods -A -o wide --field-selector=status.phase=Pending` | Adjust node group auto-scaling or add capacity |

### Security Issues

| Issue | Debugging Command | Solution |
|-------|-------------------|----------|
| External Secrets sync failure | `kubectl describe externalsecret <name>` | Check IAM permissions and Secrets Manager access |
| Pod security violations | `kubectl get events --field-selector reason=FailedCreate` | Update security context to comply with Pod Security Standards |
| Certificate issues | `kubectl describe secret <tls-secret>` | Verify certificate chain is valid and not expired |
| Authentication failures | `kubectl logs -n kube-system -l k8s-app=kube-apiserver` | Check IAM roles and OIDC provider configuration |

## Rational Running Times

| Component | Startup Time | Response Time | Scaling Time | Notes |
|-----------|--------------|--------------|--------------|-------|
| EKS Cluster | 10-15 min | N/A | N/A | Control plane provisioning can occasionally take up to 20-25 min |
| Node Groups | 5-10 min | N/A | 3-5 min for scaling | Time to join cluster after node creation: 1-2 min |
| Python App | 10-30 sec | <500ms | <30 sec with HPA | Memory usage: 100-300MB per pod |
| MySQL | 1-2 min | <100ms per query | N/A | Initialization with data import can take 5+ min |
| Elasticsearch | 2-3 min | <200ms per query | N/A | JVM heap warmup can add 1-2 min |
| Fluentd | <1 min | <5 sec log delivery | N/A | Log buffer flush interval: 60 sec |
| Prometheus | 1-2 min | <500ms per query | N/A | Compaction can cause brief slowdowns |
| Grafana | <1 min | <3 sec dashboard load | N/A | First load may be slower due to caching |
| Karpenter | <1 min | <30 sec to decision | 1-2 min for new node | API rate limiting can add delays |
| KEDA | <1 min | <30 sec to scale out | 1-3 min to scale in | Cooldown periods affect timing |
| Argo CD | 1-2 min | <30 sec for sync | N/A | Large app syncs can take 3-5 min |
| LoadBalancer | 2-5 min | <100ms | N/A | Target registration: 30-60 sec |

These timings represent average expected values in a healthy system. Significant deviations from these ranges indicate potential issues that should be investigated using the debugging commands in this guide.