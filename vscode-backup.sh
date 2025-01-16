#!/bin/bash

VSCODE_DIR="${HOME}/.config/Code/User"
OUTPUT_DIR="./assets/vscode"

mkdir -p "${OUTPUT_DIR}"

cp "${VSCODE_DIR}/settings.json" "${OUTPUT_DIR}/"
cp "${VSCODE_DIR}/keybindings.json" "${OUTPUT_DIR}/"

code --list-extensions > "$OUTPUT_DIR/extensions-list.txt"

PROFILES_DIR="${VSCODE_DIR}/profiles"
if [[ -d "${PROFILES_DIR}" ]]; then
  cp -r "${PROFILES_DIR}" "${OUTPUT_DIR}/"
fi

# Iterate over each profile and export its extensions
for profile in "GoHugo" "Shell and Node" "PHP and WebDev"; do
  echo "Exporting extensions for profile: ${profile}"
  code --profile "${profile}" --list-extensions > "${OUTPUT_DIR}/${profile}.extensions.txt"
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to export extensions for profile '${profile}'."
  else
    echo "Extensions for profile '${profile}' exported successfully."
  fi
done
