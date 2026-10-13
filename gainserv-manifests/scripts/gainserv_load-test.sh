#!/bin/bash

# ============================================
# Gainserv Load Test - HPA scaling
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="gainserv"
ALB_HOST="$(kubectl get ingress gainserv-app-server-prod-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

DURATION="${1:-300}"
CLIENTS="${2:-40}"
URL="http://$ALB_HOST/compute?iterations=20000000"   # ~50ms CPU per request
RESULTS="/tmp/gainserv-load-results.txt"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Gainserv Load Test${NC}"
echo -e "${BLUE}=========================================${NC}"
echo "URL:      $URL"
echo "Clients:  $CLIENTS"
echo "Duration: ${DURATION}s"
echo ""

END=$(( $(date +%s) + DURATION ))
worker() {
    while [ "$(date +%s)" -lt "$END" ]; do
        curl -s -o /dev/null -w '%{http_code}\n' --max-time 30 "$URL" || echo "000"
    done
}
export -f worker
export URL END
seq "$CLIENTS" | xargs -P "$CLIENTS" -I{} bash -c worker > "$RESULTS"

echo -e "${GREEN}Load finished. Response codes:${NC}"
sort "$RESULTS" | uniq -c
echo ""
echo -e "${YELLOW}Now watch the HPA scale back down (5 min wait, then -2 pods/min).${NC}"
