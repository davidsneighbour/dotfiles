#!/bin/bash

curl -fsSL https://ollama.com/install.sh | sh

docker compose down
docker compose pull --remove-orphans
docker compose up -d

ollama list | awk 'NR>1 && NF {print $1}' | while read -r model; do
  echo "Updating: ${model}"
  if ! ollama pull "${model}"; then
    echo "ERROR: failed to update ${model}" >&2
  fi
done
