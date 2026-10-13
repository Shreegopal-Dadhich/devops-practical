#!/bin/bash

# ============================================
# Gainserv Status Check Script
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="gainserv"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Gainserv Kubernetes Status${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check namespace exists
if ! kubectl get namespace $NAMESPACE &>/dev/null; then
    echo -e "${RED}Namespace '$NAMESPACE' does not exist${NC}"
    exit 1
fi

# Nodes
echo -e "${GREEN}Nodes (pool / capacity type):${NC}"
kubectl get nodes -L node-pool,eks.amazonaws.com/capacityType,topology.kubernetes.io/zone
echo ""

# Pods
echo -e "${GREEN}Pods:${NC}"
kubectl get pods -n $NAMESPACE -o wide
echo ""

# Deployments
echo -e "${GREEN}Deployments:${NC}"
kubectl get deployments -n $NAMESPACE
echo ""

# HPA
echo -e "${GREEN}Horizontal Pod Autoscaler:${NC}"
kubectl get hpa -n $NAMESPACE
echo ""

# Services / Ingress
echo -e "${GREEN}Services:${NC}"
kubectl get svc -n $NAMESPACE
echo ""
echo -e "${GREEN}Ingress:${NC}"
kubectl get ingress -n $NAMESPACE
echo ""

# Secrets sync
echo -e "${GREEN}External Secrets:${NC}"
kubectl get externalsecret -n $NAMESPACE
echo ""

# Network policies
echo -e "${GREEN}Network Policies:${NC}"
kubectl get networkpolicy -n $NAMESPACE
echo ""

# Resource usage
echo -e "${GREEN}Pod resource usage:${NC}"
kubectl top pods -n $NAMESPACE 2>/dev/null || echo -e "${YELLOW}metrics not available yet${NC}"
