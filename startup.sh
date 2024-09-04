#!/bin/bash
set -eo pipefail

# create dir
mkdir -p /workspace/felafax-storage

# mount gcsfuse
# if [ "$MOUNT_GCSFUSE" = "1" ]; then
#   if [ "$UID" != "0" ]; then
#     echo "Mounting only directory $UID"
#     gcsfuse --implicit-dirs --only-dir "$UID" $CLOUD_STORAGE_BUCKET "/workspace/felafax-storage/"
#   else
#     echo "Mounting entire bucket"
#     gcsfuse --implicit-dirs $CLOUD_STORAGE_BUCKET "/workspace/felafax-storage/"
#   fi
# fi
#
echo "Mounting entire bucket"
gcsfuse --implicit-dirs $CLOUD_STORAGE_BUCKET "/workspace/felafax-storage/"

# Check if the mounted directory is empty
if [ -z "$(ls -A /workspace/felafax-storage/)" ]; then
  echo "Mounted directory is empty. Retrying mount..."
  fusermount -u "/workspace/felafax-storage/"
  gcsfuse --implicit-dirs $CLOUD_STORAGE_BUCKET "/workspace/felafax-storage/"

  # Check again after retry
  if [ -z "$(ls -A /workspace/felafax-storage/)" ]; then
    echo "Error: Failed to mount the bucket. Directory is still empty after retry." >&2
    exit 1
  fi
fi

# run vLLM from local model
if [ -n "$MODEL_PATH" ] && [ -d "/workspace/felafax-storage/$MODEL_PATH" ]; then
  # local model path
  target_dir="/workspace/$MODEL_PATH"
  mkdir -p "$target_dir"

  # copy the model locally from gcsfuse
  time cp -R "/workspace/felafax-storage/$MODEL_PATH"/* "$target_dir"
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
