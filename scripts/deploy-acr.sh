#!/usr/bin/env bash
set -euo pipefail

: "${ACR_REGISTRY:?Set ACR_REGISTRY, for example registry-intl.ap-southeast-1.aliyuncs.com}"
: "${ACR_NAMESPACE:?Set ACR_NAMESPACE}"
: "${ACR_REPOSITORY:=dosclaw-qwen}"
: "${IMAGE_TAG:=hackathon-2026-06-13}"

IMAGE="$ACR_REGISTRY/$ACR_NAMESPACE/$ACR_REPOSITORY:$IMAGE_TAG"

docker build -t dosclaw-qwen:local .
docker tag dosclaw-qwen:local "$IMAGE"
docker push "$IMAGE"

echo "$IMAGE"
