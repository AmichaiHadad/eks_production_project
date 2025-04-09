# Monitoring Stack

This chart deploys the monitoring stack including Prometheus, Grafana, Alertmanager, and exporters.

## Prerequisites

Before deploying this chart, you must:

1. Install the Prometheus CRDs (handled by pre-install job)
2. Create the Slack webhook secret manually:

```bash
# Create the Slack webhook secret
kubectl create secret generic alertmanager-slack-webhook \
  -n monitoring \
  --from-literal=slack_webhook_url="https://hooks.slack.com/services/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"
```

## Configuration

Key settings:
- Make sure `prometheusOperator.createCustomResource: false` in values.yaml
- Storage class is configured to use `gp2` (EKS default)
- Configured to run on monitoring node group via nodeSelector/tolerations
- Ingress configured for Grafana at grafana.blizzard.co.il

## Installation Notes

1. The chart automatically installs Prometheus CRDs through a pre-install Job
2. Alertmanager configuration uses a simple AlertmanagerConfig CRD
3. Grafana is exposed via an ALB ingress with DNS provided by ExternalDNS
4. MySQL and Elasticsearch exporters are included for complete monitoring

## Troubleshooting

If deployment fails:
1. Check if the Slack webhook secret exists:
   ```bash
   kubectl get secret -n monitoring alertmanager-slack-webhook
   ```
2. Verify CRDs were successfully installed:
   ```bash
   kubectl get crds | grep monitoring.coreos.com
   ```
3. Make sure node groups have the correct labels and taints

For full cleanup before reinstallation, use:
```bash
./cleanup-monitoring-force.sh
```