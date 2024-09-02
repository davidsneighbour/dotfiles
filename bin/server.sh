#!/bin/bash

docker run -d \
  -p 3000:8080 \
  -v ollama:/root/.ollama \
  -v open-webui:/home/patrick/github.com/davidsneighbour/alan/brain --name open-webui \
  --restart always \
  \
  -e WEBUI_AUTH=false \
  -e WEBUI_NAME="Alan" \
  -e ENABLE_COMMUNITY_SHARING=false \
  \
  ghcr.io/open-webui/open-webui:ollama
