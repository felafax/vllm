#!/bin/bash

MODEL=""
if [ -n "$GCS_MODEL_PATH" ]; then
  echo "Copying model files to persistent disk..."
  mkdir -p /mnt/persistent-disk/model
  gsutil -m cp -r gs://$GCS_MODEL_PATH/* /mnt/persistent-disk/model
elif [ -n "$HF_PATH" ]; then
  MODEL="$HF_PATH"
fi

echo "vllm serve..."
exec vllm serve $MODEL --dtype auto
