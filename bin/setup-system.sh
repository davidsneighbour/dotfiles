#!/usr/bin/env bash

REQUIRED_TOOLS=(
    curl
)

for tool in ${REQUIRED_TOOLS[@]}; do
  if ! command -v ${tool} >/dev/null; then
    echo "${tool} is required... "
    exit 1
  fi
done

echo "Installing Rust and Cargo"
curl https://sh.rustup.rs -sSf | sh

echo "Completed in ${SECONDS}s"
