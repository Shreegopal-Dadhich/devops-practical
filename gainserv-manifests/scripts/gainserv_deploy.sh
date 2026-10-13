#!/bin/bash

# ============================================
# Gainserv Complete Deployment Script
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$SCRIPT_DIR/.."
COMMON_DIR="$BASE_DIR/common"
APP_SERVER_DIR="$BASE_DIR/app-server"
TF_DIR="$BASE_DIR/../gainserv-infra-prod"

NAMESPACE="gainserv"
IMAGE="$1"

if [ -z "$IMAGE" ]; then
    echo -e "${RED}ERROR: usage: ./gainserv_deploy.sh <image>${NC}"
    exit 1
fi

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Gainserv Kubernetes Deployment${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if tools are available
for tool in kubectl terraform aws jq envsubst; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}ERROR: $tool is not installed or not in PATH${NC}"
        exit 1
    fi
done

TF_OUTPUTS="$(terraform -chdir="$TF_DIR" output -json -no-color 2>/dev/null | sed -n '/^{/,/^}/p')"
# tf_out <output> [key]  e.g. tf_out irsa_role_arns '"app-server"'
tf_out() { echo "$TF_OUTPUTS" | jq -r ".$1.value${2:+.$2}"; }
export IMAGE
export AWS_REGION="$(tf_out aws_region)"
export APP_DATA_BUCKET="$(tf_out app_data_bucket)"
export ALB_SOURCE_CIDR="$(tf_out alb_source_cidr)"
export VPC_CIDR="$(tf_out vpc_cidr)"
export SSM_PREFIX="$(tf_out ssm_prefix)"
export APP_ROLE_ARN="$(tf_out irsa_role_arns '"app-server"')"
export SECRETS_READER_ROLE_ARN="$(tf_out irsa_role_arns '"app-server-secrets-reader"')"
CLUSTER_NAME="$(tf_out cluster_name)"

for v in AWS_REGION APP_DATA_BUCKET ALB_SOURCE_CIDR VPC_CIDR SSM_PREFIX APP_ROLE_ARN SECRETS_READER_ROLE_ARN CLUSTER_NAME; do
    if [ -z "${!v}" ] || [ "${!v}" = "null" ]; then
        echo -e "${RED}ERROR: $v is empty - run terraform apply first${NC}"
        exit 1
    fi
done

# Only these placeholders are replaced
VARS='${IMAGE} ${AWS_REGION} ${APP_DATA_BUCKET} ${ALB_SOURCE_CIDR} ${VPC_CIDR} ${SSM_PREFIX} ${APP_ROLE_ARN} ${SECRETS_READER_ROLE_ARN}'
apply() {
    envsubst "$VARS" < "$1" | kubectl apply -f -
}

# Step 1: Connect kubectl to the cluster
echo -e "${GREEN}[1/9] Connecting kubectl to $CLUSTER_NAME...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
echo ""

# Step 2: Create namespace
echo -e "${GREEN}[2/9] Creating namespace...${NC}"
apply "$COMMON_DIR/gainserv_common_namespace.yaml"
apply "$COMMON_DIR/gainserv_common_resourcequota.yaml"
echo ""

echo -e "${GREEN}[3/9] Applying network policies...${NC}"
apply "$COMMON_DIR/gainserv_common_networkpolicy.yaml"
apply "$APP_SERVER_DIR/gainserv_app-server_networkpolicy.yaml"
echo ""

# Step 4: ServiceAccounts (IRSA)
echo -e "${GREEN}[4/9] Creating service accounts...${NC}"
apply "$APP_SERVER_DIR/gainserv_app-server_serviceaccount.yaml"
echo ""

# Step 5: ConfigMap + secrets from SSM
echo -e "${GREEN}[5/9] Creating config and secrets (SSM -> External Secrets)...${NC}"
apply "$APP_SERVER_DIR/gainserv_app-server_secrets.yaml"
echo ""

# Step 6: Wait for the secret to sync
echo -e "${YELLOW}[6/9] Waiting for External Secrets to sync (timeout: 120s)...${NC}"
if kubectl wait externalsecret/gainserv-app-server-prod-env-secret -n $NAMESPACE --for=condition=Ready --timeout=120s; then
    echo -e "${GREEN}Secret synced${NC}"
else
    echo -e "${RED}ERROR: secret not synced - check: kubectl describe externalsecret -n $NAMESPACE${NC}"
    exit 1
fi
echo ""

echo -e "${GREEN}[7/9] Deploying app server...${NC}"
apply "$APP_SERVER_DIR/gainserv_app-server_ingress.yaml"
# The Service must exist for the controller to create the target group
apply_service_only() {
    envsubst "$VARS" < "$APP_SERVER_DIR/gainserv_app-server_deployment.yaml" | awk 'BEGIN{RS="---"} /kind: Service/' | kubectl apply -f -
}
apply_service_only
echo -e "${YELLOW}Waiting for the ALB target group (timeout: 120s)...${NC}"
for i in $(seq 1 24); do
    kubectl get targetgroupbinding -n $NAMESPACE --no-headers 2>/dev/null | grep -q . && break
    sleep 5
done
apply "$APP_SERVER_DIR/gainserv_app-server_deployment.yaml"
echo ""

# Step 8: PDB + HPA
echo -e "${GREEN}[8/9] Applying PDB and HPA...${NC}"
apply "$APP_SERVER_DIR/gainserv_app-server_pdb.yaml"
apply "$APP_SERVER_DIR/gainserv_app-server_hpa.yaml"
echo ""

# Step 9: Wait for rollout
echo -e "${YELLOW}[9/9] Waiting for rollout (timeout: 300s)...${NC}"
kubectl rollout status deployment/gainserv-app-server-prod -n $NAMESPACE --timeout=300s
echo ""

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Deployment complete${NC}"
echo -e "${BLUE}=========================================${NC}"
kubectl get pods -n $NAMESPACE -o wide
echo ""
echo -e "${GREEN}ALB URL (first time takes ~2-3 min to become reachable):${NC}"
kubectl get ingress gainserv-app-server-prod-ingress -n $NAMESPACE -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}{"\n"}'
