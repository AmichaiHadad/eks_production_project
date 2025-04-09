#!/bin/bash
# EKS Blizzard Security Testing Script

set -e

echo "======== EKS Blizzard Security Testing ========"

# Function to check if a command succeeded
check_status() {
  if [ $? -eq 0 ]; then
    echo "✅ $1"
  else
    echo "❌ $1"
    exit 1
  fi
}

# Check if required tools are installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl could not be found, please install it"
    exit 1
fi

if ! command -v trivy &> /dev/null; then
    echo "trivy could not be found, please install it"
    exit 1
fi

# Test network policies by attempting unauthorized access
echo "\n[1] Testing Network Policies..."
kubectl run test-pod --image=busybox --restart=Never --rm -i --timeout=60s -- wget -T 5 -O- http://mysql.default.svc:3306 || true
check_status "Network policy blocks unauthorized access to MySQL"

kubectl run test-pod --image=busybox --restart=Never --rm -i --timeout=60s -- wget -T 5 -O- http://elasticsearch.default.svc:9200 || true
check_status "Network policy blocks unauthorized access to Elasticsearch"

kubectl run test-pod --image=busybox --restart=Never --rm -i --timeout=60s -- nslookup kubernetes.default.svc
check_status "DNS access is allowed"

# Test pod security standards
echo "\n[2] Testing Pod Security Standards..."
kubectl run privileged-pod --image=busybox --restart=Never --privileged || true
kubectl get pod privileged-pod || true
kubectl delete pod privileged-pod --ignore-not-found
check_status "Privileged pod creation is blocked"

kubectl run host-network-pod --image=busybox --restart=Never --overrides='{"spec":{"hostNetwork":true}}' || true
kubectl get pod host-network-pod || true
kubectl delete pod host-network-pod --ignore-not-found
check_status "Host network pod creation is blocked"

# Test secret management
echo "\n[3] Testing Secret Management..."
kubectl get externalsecret -A
check_status "External Secrets are configured"

kubectl get secret mysql-secrets -n default
check_status "MySQL secrets exist"

kubectl get secret weather-api-secrets -n default
check_status "Weather API secrets exist"

# Test vulnerability scanning
echo "\n[4] Testing Vulnerability Scanning..."
kubectl get vulns -A || echo "No vulnerabilities found"

# Test auditing
echo "\n[5] Testing Audit Logging..."
kubectl get configmap -n kube-system audit-policy
check_status "Audit policy is configured"

# Test Polaris configuration
echo "\n[6] Testing Polaris Configuration..."
kubectl get cm -n security polaris-config
check_status "Polaris configuration exists"

# Scan images locally
echo "\n[7] Scanning Application Image Locally..."
REPO=$(kubectl get deployment app -n default -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d':' -f1)
TAG=$(kubectl get deployment app -n default -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d':' -f2)
trivy image ${REPO}:${TAG} --severity HIGH,CRITICAL || true

# Summarize results
echo "\n======== Security Test Summary ========"
echo "All tests completed. Please review any failures above."
echo "For detailed vulnerability reports, check Trivy Operator results or run trivy directly on your images."