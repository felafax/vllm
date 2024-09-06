#!/bin/bash
set -eo pipefail

count_items() {
  find "$1" -mindepth 1 -maxdepth 1 | wc -l
}

# Define the base storage directory path
STORAGE_DIR_BASE="${STORAGE_DIR_PATH:-/workspace}"
MODEL_DIR_NAME="MODEL"

# Set the storage and model directories
STORAGE_DIR="$STORAGE_DIR_BASE/$MODEL_DIR_NAME"
echo "Storage directory: $STORAGE_DIR"

# Create storage directory
mkdir -p "$STORAGE_DIR"

if [ -n "$MODEL_PATH" ]; then
  echo "Mounting GCS bucket"
  gcsfuse --debug_fuse --debug_fs --debug_gcs --debug_http --implicit-dirs --only-dir "$MODEL_PATH" "$CLOUD_STORAGE_BUCKET" "$STORAGE_DIR"

  # Check if the mounted directory is not empty
  if [ "$(count_items "$STORAGE_DIR")" -ne 0 ]; then
    # Create a local model directory
    LOCAL_MODEL_DIR="$STORAGE_DIR_BASE/MODEL"
    mkdir -p "$LOCAL_MODEL_DIR"

    echo "Copying model files from $STORAGE_DIR to $LOCAL_MODEL_DIR"
    time cp -R "$STORAGE_DIR"/* "$LOCAL_MODEL_DIR"

    echo "Unmounting GCS bucket"
    fusermount -u "$STORAGE_DIR"

    echo "Starting vLLM server on $VLLM_PORT using local model from $LOCAL_MODEL_DIR"
    CMD="python3 -m vllm.entrypoints.openai.api_server --model $LOCAL_MODEL_DIR --port $VLLM_PORT --dtype auto"
  else
    echo "Error: Mounted directory is empty" >&2
    exit 1
  fi
elif [ -n "$HF_PATH" ]; then
  echo "Using Hugging Face model from $HF_PATH"
  export HUGGING_FACE_HUB_TOKEN=$HF_TOKEN
  echo "Starting vLLM server on $VLLM_PORT using model $HF_PATH"
  CMD="python3 -m vllm.entrypoints.openai.api_server --model $HF_PATH --port $VLLM_PORT --dtype auto"
else
  echo "Error: Neither MODEL_PATH nor HF_PATH is set" >&2
  exit 1
fi

# Execute the command
exec $CMD
