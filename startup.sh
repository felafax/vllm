#!/bin/bash
set -eo pipefail

if [ "$MOUNT_GCSFUSE" = "1" ]; then
  if [ "$UID" != "0" ]; then
    gcsfuse --implicit-dirs --only-dir "$UID" felafax-storage "/workspace/felafax-storage/"
  else
    gcsfuse --implicit-dirs felafax-storage "/workspace/felafax-storage/"
  fi
fi

# vllm
ENTRYPOINT ["python3", "-m", "vllm.entrypoints.openai.api_server"]
