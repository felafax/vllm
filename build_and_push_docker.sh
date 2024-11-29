#!/bin/bash

# Set the Docker image name and tag
IMAGE_NAME="gcr.io/felafax-training/vllm"
IMAGE_TAG="latest_v4"

# Build the Docker image
echo "Building Docker image... ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -f Dockerfile.felafax.tpu -t ${IMAGE_NAME}:${IMAGE_TAG} .

# Check if the build was successful
if [ $? -eq 0 ]; then
  echo "Docker image built successfully."

  # Push the Docker image
  echo "Pushing Docker image to GCR..."
  docker push ${IMAGE_NAME}:${IMAGE_TAG}

  if [ $? -eq 0 ]; then
    echo "Docker image pushed successfully."
  else
    echo "Failed to push Docker image."
    exit 1
  fi
else
  echo "Docker build failed."
  exit 1
fi

echo "Script completed successfully."
