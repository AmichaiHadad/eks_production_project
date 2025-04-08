#!/bin/bash

# Cleanup script for monitoring stack
# This script removes all resources created by the monitoring ApplicationSet

set -e

echo "Starting cleanup of monitoring resources..."

# First delete the ApplicationSet
echo "Deleting ApplicationSet..."
kubectl delete -f argocd/monitoring-applicationset.yaml --ignore-not-found

# Wait a bit for ArgoCD to process the deletion
echo "Waiting for ArgoCD to process deletion..."
sleep 5

# Delete the Prometheus monitoring resources
echo "Deleting Prometheus CRDs and resources..."
kubectl delete prometheusrules --all -n monitoring --ignore-not-found
kubectl delete servicemonitors --all -n monitoring --ignore-not-found
kubectl delete podmonitors --all -n monitoring --ignore-not-found
kubectl delete alertmanagers --all -n monitoring --ignore-not-found
kubectl delete prometheuses --all -n monitoring --ignore-not-found
kubectl delete thanosrulers --all -n monitoring --ignore-not-found

# Delete Helm releases manually
echo "Deleting Helm releases..."
kubectl delete secret -n monitoring -l owner=helm --ignore-not-found
kubectl delete secret -n monitoring -l status=deployed --ignore-not-found

# Delete ConfigMaps
echo "Deleting ConfigMaps..."
kubectl delete configmap -n monitoring --all --ignore-not-found

# Delete Services
echo "Deleting Services..."
kubectl delete service -n monitoring --all --ignore-not-found

# Delete Deployments
echo "Deleting Deployments..."
kubectl delete deployment -n monitoring --all --ignore-not-found

# Delete StatefulSets
echo "Deleting StatefulSets..."
kubectl delete statefulset -n monitoring --all --ignore-not-found

# Delete DaemonSets
echo "Deleting DaemonSets..."
kubectl delete daemonset -n monitoring --all --ignore-not-found

# Delete Ingresses
echo "Deleting Ingresses..."
kubectl delete ingress -n monitoring --all --ignore-not-found

# Delete Secrets
echo "Deleting Secrets..."
kubectl delete secret -n monitoring --all --ignore-not-found

# Delete PVCs (this will trigger PV deletion if reclaim policy is Delete)
echo "Deleting PVCs..."
kubectl delete pvc -n monitoring --all --ignore-not-found

# Verify if any PVs are still associated with the monitoring namespace
echo "Checking for orphaned PVs..."
ORPHANED_PVS=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace == "monitoring") | .metadata.name')
if [ -n "$ORPHANED_PVS" ]; then
  echo "Found orphaned PVs. Deleting them..."
  for PV in $ORPHANED_PVS; do
    kubectl delete pv $PV --ignore-not-found
  done
fi

# Finally delete the namespace itself (this should clean up any remaining resources)
echo "Deleting monitoring namespace..."
kubectl delete namespace monitoring --ignore-not-found

echo "Monitoring stack cleanup completed."
echo "Note: If there are any resources still stuck in Terminating state, you may need to"
echo "manually remove the finalizers. Check with:"
echo "kubectl get all -n monitoring"
echo
echo "To force delete resources with finalizers, use:"
echo "kubectl patch <resource> <name> -n monitoring -p '{\"metadata\":{\"finalizers\":[]}}' --type=merge"