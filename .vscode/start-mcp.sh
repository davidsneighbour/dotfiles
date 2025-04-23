#!/bin/bash

# exporting loading .env file
load_env

# shellcheck disable=SC2154 # defined in .env
docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}" \
  ghcr.io/github/github-mcp-server
