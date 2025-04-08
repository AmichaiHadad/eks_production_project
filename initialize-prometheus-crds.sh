#!/bin/bash

# Initialize Prometheus CRDs properly
echo "Installing Prometheus CRDs properly..."

# First, let's install the latest Prometheus CRDs from the official repository
kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml

# Now modify our values.yaml to not attempt to create CRDs since we've done it manually
sed -i 's/createCustomResource: true/createCustomResource: false/' /mnt/d/research/eks_project_v2/helm-chart/monitoring/values.yaml

# Refresh the application
kubectl patch application -n argocd monitoring-us-east-1 -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}' --type merge

echo "Done setting up Prometheus CRDs."
echo "You can check the status with: kubectl get application monitoring-us-east-1 -n argocd -o jsonpath='{.status.health.status}'"