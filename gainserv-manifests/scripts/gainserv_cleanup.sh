#!/bin/bash

# ============================================
# Gainserv Cleanup Script
# ============================================

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

NAMESPACE="gainserv"

echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}  Gainserv Kubernetes Cleanup${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo ""

read -p "Are you sure you want to delete all Gainserv resources? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${RED}Deleting resources...${NC}"
echo ""

# Delete Ingress first - the controller deletes the ALB
echo "Deleting Ingress (removes the ALB)..."
kubectl delete ingress --all -n $NAMESPACE --ignore-not-found
echo "Waiting 60s for the ALB to be removed..."
sleep 60

# Delete namespace (everything else inside it)
echo "Deleting namespace $NAMESPACE..."
kubectl delete namespace $NAMESPACE --ignore-not-found

echo ""
echo -e "${GREEN}Cleanup complete. Now you can run: terraform destroy -var-file=prod.tfvars${NC}"
