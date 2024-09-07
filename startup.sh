#!/bin/bash
set -eo pipefail

count_items() {
  find "$1" -mindepth 1 -maxdepth 1 | wc -l
}

# Define the base storage directory path
STORAGE_DIR_BASE="${STORAGE_DIR_PATH:-/workspace}"
GCS_MOUNT_DIR="gcs_mount"
LOCAL_MODEL_DIR="MODEL"

# Set the storage and model directories
GCS_MOUNT_PATH="$STORAGE_DIR_BASE/$GCS_MOUNT_DIR"
LOCAL_MODEL_PATH="$STORAGE_DIR_BASE/$LOCAL_MODEL_DIR"

echo "GCS mount path: $GCS_MOUNT_PATH"
echo "Local model path: $LOCAL_MODEL_PATH"

if [ -n "$MODEL_PATH" ]; then
  # Create GCS mount directory
  mkdir -p "$GCS_MOUNT_PATH"
  echo "Mounting GCS bucket"
  gcsfuse --debug_fuse --debug_fs --debug_gcs --debug_http --implicit-dirs --only-dir "$MODEL_PATH" "$CLOUD_STORAGE_BUCKET" "$GCS_MOUNT_PATH"

  # Check if the mounted directory is not empty
  if [ "$(count_items "$GCS_MOUNT_PATH")" -ne 0 ]; then
    # Create a local model directory
    mkdir -p "$LOCAL_MODEL_PATH"
    echo "Copying model files from $GCS_MOUNT_PATH to $LOCAL_MODEL_PATH"
    time rsync -av --delete "$GCS_MOUNT_PATH/" "$LOCAL_MODEL_PATH/"
    echo "Unmounting GCS bucket"
    fusermount -u "$GCS_MOUNT_PATH"
    echo "Starting vLLM server on $VLLM_PORT using local model from $LOCAL_MODEL_PATH"
    MODEL="$LOCAL_MODEL_PATH"
  else
    echo "Error: Mounted directory is empty" >&2
    fusermount -u "$GCS_MOUNT_PATH"
    exit 1
  fi
elif [ -n "$HF_PATH" ]; then
  echo "Using Hugging Face model from $HF_PATH"
  export HUGGING_FACE_HUB_TOKEN=$HF_TOKEN
  echo "Starting vLLM server on $VLLM_PORT using model $HF_PATH"
  MODEL="$HF_PATH"
else
  echo "Error: Neither MODEL_PATH nor HF_PATH is set" >&2
  exit 1
fi

# Construct the vllm serve command
CMD="vllm serve $MODEL --port $VLLM_PORT --host 0.0.0.0"

# Add chat template if provided
if [ -n "$CHAT_TEMPLATE" ]; then
  CMD="$CMD --chat-template $CHAT_TEMPLATE"
fi

# Add API key if provided
if [ -n "$VLLM_API_KEY" ]; then
  CMD="$CMD --api-key $VLLM_API_KEY"
fi

# Execute the command
echo "Executing command: $CMD"
exec $CMD
