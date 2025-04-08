#!/bin/bash

# Force Cleanup script for monitoring stack
# This script forcefully removes all resources related to monitoring

set -e

echo "Starting FORCEFUL cleanup of monitoring resources..."

# First check if there's an Application in ArgoCD for monitoring
MONITORING_APP=$(kubectl get applications -n argocd -o json | jq -r '.items[] | select(.metadata.name | contains("monitoring"))')
if [ -n "$MONITORING_APP" ]; then
  echo "Found monitoring application in ArgoCD. Deleting..."
  APP_NAME=$(echo $MONITORING_APP | jq -r '.metadata.name')
  kubectl patch application $APP_NAME -n argocd --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
  kubectl delete application $APP_NAME -n argocd
  echo "Waiting for application to be removed..."
  sleep 5
fi

# Check for ApplicationSet
MONITORING_APPSET=$(kubectl get applicationsets -n argocd -o json | jq -r '.items[] | select(.metadata.name | contains("monitoring"))')
if [ -n "$MONITORING_APPSET" ]; then
  echo "Found monitoring ApplicationSet in ArgoCD. Deleting..."
  APPSET_NAME=$(echo $MONITORING_APPSET | jq -r '.metadata.name')
  kubectl patch applicationset $APPSET_NAME -n argocd --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
  kubectl delete applicationset $APPSET_NAME -n argocd
  echo "Waiting for ApplicationSet to be removed..."
  sleep 5
fi

# We no longer delete the ApplicationSet YAML file to preserve the configuration
echo "Note: The monitoring-applicationset.yaml file is being preserved for future deployments."

# Force delete all ExternalSecrets resources
echo "Force deleting ExternalSecrets resources..."
kubectl delete externalsecret -n monitoring --all --force --grace-period=0 2>/dev/null || true
kubectl delete secretstore -n monitoring --all --force --grace-period=0 2>/dev/null || true
kubectl delete clustersecretstore --all --force --grace-period=0 2>/dev/null || true

# Force delete all CRDs related to monitoring
echo "Force deleting Prometheus CRDs in monitoring namespace..."
for CRD in prometheusrules servicemonitors podmonitors alertmangers prometheuses externalsecrets secretstores; do
  kubectl get $CRD -n monitoring -o name 2>/dev/null | xargs -r -I{} kubectl patch {} -n monitoring --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
  kubectl delete $CRD -n monitoring --all --force --grace-period=0 2>/dev/null || true
done

# Force delete all resources in monitoring namespace
echo "Force deleting all resources in monitoring namespace..."
for RESOURCE in deployment statefulset daemonset configmap secret service ingress pvc pv; do
  kubectl get $RESOURCE -n monitoring -o name 2>/dev/null | xargs -r -I{} kubectl patch {} -n monitoring --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
  kubectl delete $RESOURCE -n monitoring --all --force --grace-period=0 2>/dev/null || true
done

# Force delete all pods
echo "Force deleting all pods in monitoring namespace..."
kubectl delete pods -n monitoring --all --force --grace-period=0 2>/dev/null || true

# Check for orphaned PVs
echo "Checking for PVs associated with monitoring namespace..."
ORPHANED_PVS=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace == "monitoring") | .metadata.name')
if [ -n "$ORPHANED_PVS" ]; then
  echo "Found orphaned PVs. Force deleting them..."
  for PV in $ORPHANED_PVS; do
    kubectl patch pv $PV --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
    kubectl delete pv $PV --force --grace-period=0 || true
  done
fi

# Finally, force delete the namespace itself
echo "Force deleting monitoring namespace..."
kubectl get namespace monitoring -o json | jq '.spec.finalizers = []' > temp.json
if [ -s temp.json ]; then
  kubectl replace --raw "/api/v1/namespaces/monitoring/finalize" -f temp.json || true
  rm temp.json
fi
kubectl delete namespace monitoring --force --grace-period=0 || true

# Check for any stuck resources
echo "Checking for any remaining resources in monitoring namespace..."
REMAINING=$(kubectl get all -n monitoring 2>/dev/null)
if [ -n "$REMAINING" ]; then
  echo "WARNING: There are still resources in the monitoring namespace:"
  echo "$REMAINING"
  echo "You may need to manually remove them using kubectl patch or the Kubernetes API"
else
  echo "All resources in monitoring namespace successfully removed."
fi

echo "Monitoring stack cleanup completed."
echo "You may need to also delete any other ApplicationSets that might be creating monitoring resources."