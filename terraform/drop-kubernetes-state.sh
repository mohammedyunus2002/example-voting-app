#!/usr/bin/env bash
# The Kubernetes provider cannot refresh or delete objects after the EKS API
# hostname is gone. Drop those objects from state and let a later apply recreate them.
set -u

region="${AWS_REGION:-us-east-2}"
if aws eks describe-cluster --name staging-demo --region "${region}" >/dev/null 2>&1; then
  exit 0
fi

echo "EKS API is already gone. Removing Kubernetes and Helm resources from state."
terraform state list | grep -E '^(kubernetes_|helm_release\.)' | while read -r addr; do
  echo "state rm ${addr}"
  terraform state rm "${addr}"
done || true
