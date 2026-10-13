#!/bin/bash

# ============================================
# Gainserv Build & Push Script
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$SCRIPT_DIR/../.."
TF_DIR="$REPO_DIR/gainserv-infra-prod"

TF_OUTPUTS="$(terraform -chdir="$TF_DIR" output -json -no-color 2>/dev/null | sed -n '/^{/,/^}/p')"
# tf_out <output> [key]  e.g. tf_out irsa_role_arns '"app-server"'
tf_out() { echo "$TF_OUTPUTS" | jq -r ".$1.value${2:+.$2}"; }

TAG="${1:-$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"
AWS_REGION="$(tf_out aws_region)"
ECR_REPO="$(tf_out ecr_repository_url)"
ECR_REGISTRY="${ECR_REPO%%/*}"
IMAGE="$ECR_REPO:$TAG"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Gainserv Build & Push${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${GREEN}[1/4] Logging in to ECR...${NC}"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
echo ""

echo -e "${GREEN}[2/4] Building $IMAGE...${NC}"
# EKS nodes are x86_64 - build for that even on an ARM laptop
docker build --platform linux/amd64 -t "$IMAGE" "$REPO_DIR"
echo ""

echo -e "${GREEN}[3/4] Pushing...${NC}"
docker push "$IMAGE"
echo ""

echo -e "${YELLOW}[4/4] ECR scan-on-push results...${NC}"
aws ecr wait image-scan-complete --region "$AWS_REGION" --repository-name "${ECR_REPO#*/}" --image-id imageTag="$TAG" 2>/dev/null || true
aws ecr describe-image-scan-findings --region "$AWS_REGION" --repository-name "${ECR_REPO#*/}" --image-id imageTag="$TAG" \
  --query 'imageScanFindings.findingSeverityCounts' --output table 2>/dev/null || echo "  (scan not finished yet)"
echo ""

echo -e "${BLUE}Image: $IMAGE${NC}"
echo "Deploy with: ./gainserv_deploy.sh $IMAGE"
