#!/bin/bash

# ============================================
# Gainserv Network Policy Test
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="gainserv"
ALB_HOST="$(kubectl get ingress gainserv-app-server-prod-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

SVC_URL="http://gainserv-app-server-prod-svc.gainserv.svc.cluster.local:3000/healthz"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Gainserv Network Policy Test${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${GREEN}[1/2] From a pod in the default namespace (expect BLOCKED)...${NC}"
if kubectl run np-test -n default --rm -i --restart=Never --quiet \
    --image=curlimages/curl:8.11.1 -- -sS --max-time 5 "$SVC_URL"; then
    echo -e "${RED}UNEXPECTED: reached the app${NC}"
else
    echo -e "${GREEN}BLOCKED (as intended)${NC}"
fi
echo ""

echo -e "${GREEN}[2/2] Through the ALB (expect 'ok')...${NC}"
curl -sS --max-time 10 "http://$ALB_HOST/healthz"; echo
