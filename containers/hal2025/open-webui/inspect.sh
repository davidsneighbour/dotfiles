#!/bin/bash

# Check container status
docker ps -f name=open-webui

# View logs (like journalctl -u ollama)
docker logs -f open-webui

# Inspect running processes inside
docker exec -it open-webui ps aux

# Health via Docker Compose

docker compose ps
docker compose logs -f open-webui

# Inspect container details
docker inspect open-webui
