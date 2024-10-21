#!/bin/bash
MODEL=""
if [ -n "$GCS_MODEL_PATH" ]; then
  echo "Copying model files to persistent disk..."
  mkdir -p /mnt/persistent-disk/model

  gsutil -m cp -r "${GCS_MODEL_PATH%/}"/* /mnt/persistent-disk/model
  MODEL="/mnt/persistent-disk/model"

  echo "vllm serve... {model: $MODEL}"
  exec vllm serve $MODEL --tokenizer "/mnt/persistent-disk/model" --enforce-eager

elif [ -n "$HF_PATH" ]; then
  MODEL="$HF_PATH"

  echo "vllm serve... {model: $MODEL}"
  exec vllm serve $MODEL  --enforce-eager
fi
