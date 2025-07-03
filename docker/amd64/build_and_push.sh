#!/bin/bash

# Set variables
APP=dify-sandbox
VERSION=0.2.12.$(date "+%Y%m%d%H%M")
NAMESPACE=open
ACR_REGISTRY=yiya-acr-registry.cn-hangzhou.cr.aliyuncs.com

# Build the Docker image
# The -f flag specifies the path to the Dockerfile relative to the project root
docker build -f docker/amd64/dockerfile -t ${ACR_REGISTRY}/${NAMESPACE}/${APP}:${VERSION} .

# Push the Docker image
docker push ${ACR_REGISTRY}/${NAMESPACE}/${APP}:${VERSION}
