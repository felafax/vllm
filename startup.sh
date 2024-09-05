#!/bin/bash
set -eo pipefail

# Define the storage directory as a variable
STORAGE_DIR="/workspace/storage"

# create dir
mkdir -p "$STORAGE_DIR"

# mount gcsfuse
echo "Mounting entire bucket"
mount -t gcsfuse -o implicit_dirs $CLOUD_STORAGE_BUCKET "$STORAGE_DIR"

# Check if the mounted directory is empty
if [ -z "$(ls -A "$STORAGE_DIR")" ]; then
  echo "Mounted directory is empty. Retrying mount..."
  fusermount -u "$STORAGE_DIR"

  # retry
  STORAGE_DIR="/workspace/storage-2"
  mkdir -p "$STORAGE_DIR"

  gcsfuse --implicit-dirs $CLOUD_STORAGE_BUCKET "$STORAGE_DIR"

  # Check again after retry
  if [ -z "$(ls -A "$STORAGE_DIR")" ]; then
    echo "Error: Failed to mount the bucket. Directory is still empty after retry." >&2
    exit 1
  fi
fi

# run vLLM from local model
if [ -n "$MODEL_PATH" ] && [ -d "$STORAGE_DIR/$MODEL_PATH" ]; then
  # local model path
  target_dir="/workspace/$MODEL_PATH"
  mkdir -p "$target_dir"
  # copy the model locally from gcsfuse
  time cp -R "$STORAGE_DIR/$MODEL_PATH"/* "$target_dir"
  echo "Using local model from $MODEL_PATH"
  # start vllm
  echo "Starting vLLM server on $VLLM_PORT and using model $target_dir"
  CMD="python3 -m vllm.entrypoints.openai.api_server --model $target_dir --port $VLLM_PORT --dtype auto"
elif [ -n "$HF_PATH" ]; then
  echo "Using Hugging Face model from $HF_PATH"
  export HUGGING_FACE_HUB_TOKEN=$HF_TOKEN
  # start vllm
  echo "Starting vLLM server on $VLLM_PORT and using model $HF_PATH"
  CMD="python3 -m vllm.entrypoints.openai.api_server $HF_PATH --port $VLLM_PORT --dtype auto"
else
  echo "Error: Neither MODEL_PATH nor HF_PATH is set" >&2
  exit 1
fi

# Execute the command
exec $CMD
