#!/bin/bash
set -eo pipefail

# create dir
mkdir -p /workspace/felafax-storage

# mount gcsfuse
if [ "$MOUNT_GCSFUSE" = "1" ]; then
  if [ "$UID" != "0" ]; then
    gcsfuse --implicit-dirs --only-dir "$UID" $CLOUD_STORAGE_BUCKET "/workspace/felafax-storage/"
  else
    gcsfuse --implicit-dirs $CLOUD_STORAGE_BUCKET "/workspace/felafax-storage/"
  fi
fi

# Check if MODEL_PATH directory exists and copy its contents to /workspace
# run vLLM from local model
if [ -n "$MODEL_PATH" ] && [ -d "/workspace/felafax-storage/$MODEL_PATH" ]; then
  target_dir="/workspace/$MODEL_PATH"
  mkdir -p "$target_dir"
  time cp -R "/workspace/felafax-storage/$MODEL_PATH"/* "$target_dir"
  echo "Using local model from $MODEL_PATH"
  CMD="python3 -m vllm.entrypoints.openai.api_server --model $target_dir --port $VLLM_PORT --dtype auto"
elif [ -n "$HF_PATH" ]; then
  echo "Using Hugging Face model from $HF_PATH"
  export HUGGING_FACE_HUB_TOKEN=$HF_TOKEN
  CMD="python3 -m vllm.entrypoints.openai.api_server $HF_PATH --port $VLLM_PORT --dtype auto"
else
  echo "Error: Neither MODEL_PATH nor HF_PATH is set" >&2
  exit 1
fi

# Execute the command
exec $CMD
