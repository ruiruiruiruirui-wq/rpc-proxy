#!/bin/bash

# 获取当前分支的commit ID
commit_id=$(git rev-parse HEAD)
branch_name=$(git branch --show-current)

# 组合tag：分支名-commitID
tag="${branch_name}-${commit_id}"
repo='onekey-container-ap-southeast-1.cr.bytepluses.com/private/v5-rpc-proxy'

echo "Building multi-platform image with tag: $tag"

# 构建多平台镜像并直接推送到仓库
docker buildx build --platform linux/amd64,linux/arm64 --push . -t $repo:$tag

echo "Build and push completed successfully!"
echo "Image: $repo:$tag (multi-platform: linux/amd64, linux/arm64)"

echo "------update deployment image"
kubectl -n onekey-v5-test set image deployment/v5-rpc-proxy v5-rpc-proxy=$repo:$tag

echo "Deployment updated successfully!"
