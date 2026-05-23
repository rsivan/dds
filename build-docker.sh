#!/bin/bash
set -e

echo "Building DDS Docker image..."
cd "$(dirname "$0")"

TAG="${1:-dds:local}"

docker build -f docker/Dockerfile -t "$TAG" .

echo "✓ Build complete"
echo "Image: $TAG"
echo ""
echo "To run: docker run --rm -it $TAG bash"
echo "To push: docker tag $TAG ghcr.io/rsivan/dds:latest && docker push ghcr.io/rsivan/dds:latest"
