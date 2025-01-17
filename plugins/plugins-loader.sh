#!/bin/bash

# Directory to store logs
LOG_DIR="${HOME}/.logs"
mkdir -p "${LOG_DIR}"

# Log file for plugin loader
LOG_FILE="${LOG_DIR}/plugins-loader.log"

# Start logging
echo "Initializing plugins at $(date)" > "${LOG_FILE}"

# Iterate through all plugins
for config in plugins/*/config.json; do
    plugin_dir=$(dirname "${config}")
    plugin_name=$(basename "${plugin_dir}")

    # Parse configuration
    script=$(jq -r '.script' "${config}")
    dependencies=$(jq -r '.dependencies | .[]?' "${config}" 2>/dev/null)

    echo "Loading plugin: ${plugin_name}" | tee -a "${LOG_FILE}"

    # Ensure the script is executable
    if [ -f "${plugin_dir}/${script}" ]; then
        chmod +x "${plugin_dir}/${script}"
        echo "  Script set as executable: ${plugin_dir}/${script}" | tee -a "${LOG_FILE}"
    else
        echo "  ERROR: Script ${plugin_dir}/${script} not found!" | tee -a "${LOG_FILE}"
        continue
    fi

    # Handle dependencies
    if [ -n "${dependencies}" ]; then
        echo "  Installing dependencies..." | tee -a "${LOG_FILE}"
        for dep in ${dependencies}; do
            echo "    Installing ${dep}" | tee -a "${LOG_FILE}"
            # Example for npm packages:
            npm install -g "${dep}" || {
                echo "    ERROR: Failed to install ${dep}!" | tee -a "${LOG_FILE}"
            }
        done
    fi

    # Execute an optional initialization step (if defined in the script)
    if [ -f "${plugin_dir}/${script}" ]; then
        "${plugin_dir}/${script}" init || echo "  Optional init step failed for ${plugin_name}" | tee -a "${LOG_FILE}"
    fi
done

echo "All plugins loaded successfully!" | tee -a "${LOG_FILE}"
