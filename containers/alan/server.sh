#!/bin/bash

docker run -d \
  --network=host \
  -v ollama:/root/.ollama \
  --add-host=host.docker.internal:host-gateway \
  -v /home/patrick/github.com/davidsneighbour/alan/brain:/app/backend/data \
  --name open-webui \
  --restart always \
  \
  -e WEBUI_AUTH=false \
  -e WEBUI_NAME="Alan" \
  -e ENABLE_COMMUNITY_SHARING=false \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  \
  ghcr.io/open-webui/open-webui:main
