#!/bin/bash

echo "Step 1: Creating temporary Dockerfile for building Linux binaries..."
cat <<EOF > Dockerfile.build_binaries
FROM --platform=linux/amd64 golang:1.23-bullseye

WORKDIR /app

COPY . .

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \\
    pkg-config \\
    libseccomp-dev \\
    gcc \\
    libc6-dev \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

# Build the binaries
RUN rm -f internal/core/runner/python/python.so \\
    && rm -f internal/core/runner/nodejs/nodejs.so \\
    && CGO_ENABLED=1 go build -o internal/core/runner/python/python.so -buildmode=c-shared -ldflags="-s -w" cmd/lib/python/main.go \\
    && CGO_ENABLED=1 go build -o internal/core/runner/nodejs/nodejs.so -buildmode=c-shared -ldflags="-s -w" cmd/lib/nodejs/main.go \\
    && go build -o main -ldflags="-s -w" cmd/server/main.go \\
    && go build -o env -ldflags="-s -w" cmd/dependencies/init.go
EOF

echo "Step 2: Building temporary Docker image..."
docker build --platform=linux/amd64 -t dify-sandbox-builder -f Dockerfile.build_binaries .

echo "Step 3: Running temporary container and copying binaries..."
CONTAINER_ID=$(docker create --platform=linux/amd64 dify-sandbox-builder)

if [ -z "$CONTAINER_ID" ]; then
    echo "Error: Failed to create container"
    exit 1
fi

# Copy binaries with error checking
docker cp ${CONTAINER_ID}:/app/main ./main || echo "Warning: Failed to copy main binary"
docker cp ${CONTAINER_ID}:/app/env ./env || echo "Warning: Failed to copy env binary"
docker cp ${CONTAINER_ID}:/app/internal/core/runner/python/python.so ./python.so || echo "Warning: Failed to copy python.so"
docker cp ${CONTAINER_ID}:/app/internal/core/runner/nodejs/nodejs.so ./nodejs.so || echo "Warning: Failed to copy nodejs.so"

echo "Step 4: Cleaning up temporary container and image..."
docker rm ${CONTAINER_ID}
docker rmi dify-sandbox-builder
rm -f Dockerfile.build_binaries

echo "Linux binaries are now available in the current directory."
ls -la main env *.so 2>/dev/null || echo "Some binaries may not have been created successfully"
