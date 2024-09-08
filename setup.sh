#!/bin/bash

MODEL=""
if [ -n "$MODEL_PATH" ]; then
  mkdir -p /workspace/gcs_mount
  mkdir -p /workspace/model

  echo "Mounting GCS bucket"
  gcsfuse --implicit-dirs --only-dir "$MODEL_PATH" "$CLOUD_STORAGE_BUCKET" /workspace/gcs_mount

  echo "Copying model files..."
  time rsync -av --delete "/workspace/gcs_mount/" "/workspace/model/"
  MODEL="/workspace/model"
elif [ -n "$HF_PATH" ]; then
  MODEL="$HF_PATH"
fi

echo "vllm serve..."
# exec python3 -m vllm.entrypoints.openai.api_server
exec vllm serve $MODEL --dtype auto
