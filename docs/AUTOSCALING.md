# Autoscaling with Karpenter and KEDA

This document provides details on the autoscaling implementation using Karpenter for node scaling and KEDA for pod scaling.

## Karpenter

Karpenter is used for just-in-time node provisioning when pods cannot be scheduled due to resource constraints.

### Configuration

- **IAM Role**: Karpenter controller requires an IAM role with permissions to create and terminate EC2 instances.
- **Provisioner**: A default provisioner that targets the following:
  - Instance types: m5.large, m5.xlarge, c5.large, c5.xlarge, r5.large
  - Capacity types: on-demand and spot instances
  - Zones: All AZs in the respective region (a, b, c)
- **Node Consolidation**: Enabled to terminate empty nodes after 60 seconds
- **TTL**: Nodes have a maximum lifetime of 12 hours to ensure fresh nodes
- **Resources Limit**: Maximum of 100 CPUs and 200Gi memory to prevent excessive scaling

### Deployment

Karpenter is deployed via Terraform/Terragrunt in each region:

```bash
cd terragrunt/us-east-1/karpenter
terragrunt apply

cd terragrunt/us-west-2/karpenter
terragrunt apply
```

## KEDA

KEDA (Kubernetes Event-driven Autoscaling) is used to scale the application based on metrics from Prometheus.

### Configuration

- **ScaledObject**: Targets the app deployment with the following settings:
  - Min replicas: 2
  - Max replicas: 10
  - Polling interval: 15 seconds
  - Cooldown period: 60 seconds
- **Trigger**: Prometheus metric query
  - Query: `sum(rate(http_requests_total{app="app"}[5m]))` 
  - Threshold: 10 requests per second

### Deployment

KEDA is deployed via Terraform/Terragrunt in each region:

```bash
cd terragrunt/us-east-1/keda
terragrunt apply

cd terragrunt/us-west-2/keda
terragrunt apply
```

## Application Metrics

The Python application has been instrumented with Prometheus metrics:

- **http_requests_total**: Counter for total HTTP requests with labels for method, endpoint, and status
- **http_request_duration_seconds**: Histogram for request latency with labels for method and endpoint
- **temperature_fetch_errors_total**: Counter for errors fetching temperature data
- **db_errors_total**: Counter for database errors

A ServiceMonitor is configured to scrape metrics from the /metrics endpoint.

## Testing Autoscaling

A load testing job is provided to simulate traffic and trigger autoscaling:

```bash
kubectl apply -f testing/load-test.yaml
```

During the test:
1. Watch pod scaling using: `kubectl get pods -l app=app -w`
2. Watch node creation with: `kubectl get nodes -l provisioning-group=karpenter -w`

## Monitoring

Monitoring for autoscaling is available in Grafana:
- KEDA ScaledObject metrics
- Karpenter provisioned nodes and events
- Application request rates and scaling events

## Alerting

Prometheus alerts have been configured for:
- High request rate (> 10 req/s)
- High error rate (> 5%)
- Slow response time (> 1s)
- Database errors
- Weather API errors

## Notes

- Karpenter nodes are labeled with `node-role=services` to match application affinity
- The application must expose Prometheus metrics on /metrics endpoint
- Both Karpenter and KEDA are deployed on the management node group