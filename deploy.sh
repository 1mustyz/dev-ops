#!/usr/bin/env bash

set -euo pipefail

IMAGE_TAG="$1"

APP_DIR="/opt/nodeapp"
AWS_REGION="us-east-1"
ECR_REGISTRY="968585507521.dkr.ecr.us-east-1.amazonaws.com"

echo "Deploying image tag: $IMAGE_TAG"

cd "$APP_DIR"

echo "Authenticating Docker with ECR..."

aws ecr get-login-password \
  --region "$AWS_REGION" \
| docker login \
  --username AWS \
  --password-stdin \
  "$ECR_REGISTRY"

echo "Updating application version..."

if grep -q '^IMAGE_TAG=' .env; then
    sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$IMAGE_TAG/" .env
else
    echo "IMAGE_TAG=$IMAGE_TAG" >> .env
fi

echo "Pulling images..."

docker compose pull

echo "Starting containers..."

docker compose up -d --remove-orphans

echo "Deployment status:"

docker compose ps

echo "Deployment complete."
