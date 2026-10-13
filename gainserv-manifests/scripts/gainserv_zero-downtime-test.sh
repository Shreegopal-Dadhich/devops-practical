#!/bin/bash

# ============================================
# Gainserv Zero Downtime Test
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="gainserv"
ALB_HOST="$(kubectl get ingress gainserv-app-server-prod-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

URL="http://$ALB_HOST/compute"
RESULTS="/tmp/gainserv-rollout-results.txt"
STOP="/tmp/gainserv-rollout-stop"
: > "$RESULTS"
rm -f "$STOP"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Gainserv Zero Downtime Test${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${GREEN}[1/3] Sending steady traffic (10 parallel clients)...${NC}"
for i in $(seq 10); do
    ( while [ ! -f "$STOP" ]; do
        curl -s -o /dev/null -w '%{http_code}\n' --max-time 10 "$URL" >> "$RESULTS" || echo "000" >> "$RESULTS"
      done ) &
done
sleep 10

echo -e "${GREEN}[2/3] Rolling every pod...${NC}"
kubectl rollout restart deployment/gainserv-app-server-prod -n $NAMESPACE
kubectl rollout status deployment/gainserv-app-server-prod -n $NAMESPACE --timeout=600s
sleep 30   # let the last old pods finish draining
touch "$STOP"; wait; rm -f "$STOP"
echo ""

echo -e "${GREEN}[3/3] Responses during the rollout:${NC}"
sort "$RESULTS" | uniq -c
FAILED=$(grep -vc '^200$' "$RESULTS")
echo "Total: $(wc -l < "$RESULTS")   Non-200: $FAILED"
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}PASS: zero dropped requests${NC}"
else
    echo -e "${RED}FAIL: $FAILED requests dropped${NC}"
    exit 1
fi
