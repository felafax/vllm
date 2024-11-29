#!/bin/bash
set -eo pipefail

# Load scripts
mkdir -p "/home/scripts/"
gsutil -m cp -r "gs://felafax-storage-v2/scripts/*" "/home/scripts/"

# Install script requirements
pip install -r "/home/scripts/requirements.txt"

# Execute the script 
if [ -n "$SCRIPT_NAME" ]; then
  python "/home/scripts/$SCRIPT_NAME"
else
  echo "No script to execute"
fi

