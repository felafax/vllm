#!/bin/bash
set -eo pipefail

# Define the base storage directory path
STORAGE_DIR_BASE="${STORAGE_DIR_PATH:-/workspace}"

# Define the primary and fallback storage directory names
PRIMARY_DIR_NAME="storage"
FALLBACK_DIR_NAME="storage-fallback"

# Set the initial storage directory
STORAGE_DIR="$STORAGE_DIR_BASE/$PRIMARY_DIR_NAME"
echo "Initial storage directory: $STORAGE_DIR"

# create dir
mkdir -p "$STORAGE_DIR"

# mount gcsfuse
echo "Mounting entire bucket"
# mount -t gcsfuse -o implicit_dirs --only-dir $MODEL_PATH $CLOUD_STORAGE_BUCKET "$STORAGE_DIR"
gcsfuse --implicit-dirs --only-dir $MODEL_PATH felafax-storage "$WORKSPACE_DIR/felafax-storage/"

# Function to count files and directories
count_items() {
  find "$1" -mindepth 1 -maxdepth 1 | wc -l
}

# Check if the mounted directory is empty
if [ "$(count_items "$STORAGE_DIR")" -eq 0 ]; then
  echo "Mounted directory is empty. Retrying mount..."
  fusermount -u "$STORAGE_DIR"
  # retry with fallback directory
  STORAGE_DIR="$STORAGE_DIR_BASE/$FALLBACK_DIR_NAME"
  echo "Retrying with fallback storage directory: $STORAGE_DIR"
  mkdir -p "$STORAGE_DIR"
  # gcsfuse --implicit-dirs $CLOUD_STORAGE_BUCKET "$STORAGE_DIR"
  gcsfuse $CLOUD_STORAGE_BUCKET "$STORAGE_DIR"
  mkdir -p "$STORAGE_DIR/$MODEL_PATH"
  # Check again after retry
  if [ "$(count_items "$STORAGE_DIR")" -eq 0 ]; then
    echo "Error: Failed to mount the bucket. Directory is still empty after retry." >&2
    exit 1
  fi
fi

# run vLLM from local model
if [ -n "$MODEL_PATH" ] && [ -d "$STORAGE_DIR/$MODEL_PATH" ]; then
  # local model path
  target_dir="$STORAGE_DIR_BASE/$MODEL_PATH"
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
