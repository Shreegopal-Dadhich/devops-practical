#!/bin/bash

# ============================================
# Gainserv IRSA Test
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TF_DIR="$SCRIPT_DIR/../../gainserv-infra-prod"
NAMESPACE="gainserv"

TF_OUTPUTS="$(terraform -chdir="$TF_DIR" output -json -no-color 2>/dev/null | sed -n '/^{/,/^}/p')"
BUCKET="$(echo "$TF_OUTPUTS" | jq -r '.app_data_bucket.value')"
AWS_REGION="$(echo "$TF_OUTPUTS" | jq -r '.aws_region.value')"
SSM_PREFIX="$(echo "$TF_OUTPUTS" | jq -r '.ssm_prefix.value')"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Gainserv IRSA Test${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Step 1: Test file in the app bucket
echo -e "${GREEN}[1/3] Uploading a test file to s3://$BUCKET...${NC}"
echo "hello from S3 - read via IRSA, no access keys" | aws s3 cp - "s3://$BUCKET/hello.txt" --region "$AWS_REGION" >/dev/null
echo ""

# Step 2: Run the test pod with the app's ServiceAccount
echo -e "${GREEN}[2/3] Running test pod as ServiceAccount gainserv-app-server-prod-sa...${NC}"
kubectl delete pod irsa-test -n $NAMESPACE --ignore-not-found >/dev/null
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: irsa-test
  namespace: $NAMESPACE
  labels:
    app: gainserv-app-server-prod # same NetworkPolicy as the app
spec:
  serviceAccountName: gainserv-app-server-prod-sa
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: aws
    image: amazon/aws-cli:2.27.0
    command: ["sh", "-c"]
    args:
    - |
      echo "== 1. Static AWS keys in the pod?"; env | grep -E 'AWS_ACCESS_KEY_ID|AWS_SECRET' || echo "   none"
      echo "== 2. What IRSA injected instead:"; env | grep -E 'AWS_ROLE_ARN|AWS_WEB_IDENTITY_TOKEN_FILE'
      echo "== 3. Who does AWS think I am?"; aws sts get-caller-identity --query Arn --output text
      echo "== 4. List own bucket (allowed):"; aws s3 ls s3://$BUCKET/
      echo "== 5. Read file (allowed):"; aws s3 cp s3://$BUCKET/hello.txt -
      echo "== 6. List ALL buckets (should be denied):"; aws s3 ls 2>&1 | tail -1
      echo "== 7. Read SSM secret (should be denied):"; aws ssm get-parameter --name $SSM_PREFIX/APP_API_KEY 2>&1 | tail -1
    env:
    - name: HOME
      value: /tmp
    - name: AWS_REGION
      value: $AWS_REGION
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    resources:
      requests: {cpu: 100m, memory: 128Mi}
      limits: {cpu: 500m, memory: 256Mi}
    readinessProbe: # never Ready -> never receives ALB traffic
      exec:
        command: ["false"]
YAML

echo -e "${YELLOW}Waiting for the test pod to finish (timeout: 180s)...${NC}"
kubectl wait pod/irsa-test -n $NAMESPACE --for=jsonpath='{.status.phase}'=Succeeded --timeout=180s >/dev/null
echo ""

# Step 3: Results
echo -e "${GREEN}[3/3] Results:${NC}"
kubectl logs irsa-test -n $NAMESPACE
kubectl delete pod irsa-test -n $NAMESPACE --wait=false >/dev/null
