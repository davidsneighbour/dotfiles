#!/bin/bash

set -euo pipefail

# ==============================================================================
# Git Monitor Script with Discord Notifications
# ==============================================================================
#
# This script monitors changes in a specified Git repository (or subdirectory),
# logs those changes, and sends Discord notifications when new commits are
# detected.
#
# Features:
# - CLI parameters to define the repository, path, log file, and output format
# - Defaults to monitoring the **current directory** if no parameters are given
# - Provides different output formats: text, diff, and filename
# - Sends alerts to Discord with commit details
# - Logs all detected changes for future reference
#
# ==============================================================================
# Usage Examples:
#
# 1. Monitor the current directory (assumes it's a Git repository):
#    ./git-monitor.sh
#
# 2. Monitor a specific repository:
#    ./git-monitor.sh --repo /path/to/local/repo
#
# 3. Monitor a specific subdirectory inside a repository:
#    ./git-monitor.sh --repo /path/to/local/repo --path tpl/tplimpl/embedded/templates
#
# 4. Save logs to a custom file:
#    ./git-monitor.sh --repo /path/to/local/repo --log /tmp/git-changes.log
#
# 5. Choose the output format:
#    # Full commit messages
#    ./git-monitor.sh --repo /path/to/local/repo --format text
#
#    # Show commit diffs
#    ./git-monitor.sh --repo /path/to/local/repo --format diff
#
#    # Show only changed filenames
#    ./git-monitor.sh --repo /path/to/local/repo --format filename
#
# ==============================================================================
# Environment Variables (Required in ~/.env):
#
# The script requires a Discord webhook URL to send notifications. Add this to
# your `~/.env` file:
#
# DISCORD_WEBHOOK="https://discord.com/api/webhooks/your_webhook_url"
#
# ==============================================================================

# Load environment variables
FILE=~/.env
if [ -f "${FILE}" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${FILE}"
  set +a
fi

# Default values
REPO_PATH=""
WATCH_PATH=""
LOG_FILE="${HOME}/.logs/git-path-monitor.log"
OUTPUT_FORMAT="text"

# Help function
usage() {
  echo "Usage: ${FUNCNAME[0]} [--repo <repo_path>] [--path <watch_path>] [--log <log_file>] [--format <text|diff|filename>]"
  echo ""
  echo "Options:"
  echo "  --repo     Path to the Git repository to monitor (optional, defaults to current directory)."
  echo "  --path     Path inside the repository to monitor (optional, defaults to entire repo)."
  echo "  --log      Output file path for logging changes (optional, defaults to ~/.logs/git-path-monitor.log)."
  echo "  --format   Output format: text (default), diff, filename."
  echo "  --help     Show this help message."
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_PATH="$2"
      shift 2
      ;;
    --path)
      WATCH_PATH="$2"
      shift 2
      ;;
    --log)
      LOG_FILE="$2"
      shift 2
      ;;
    --format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      echo "Error: Unknown option $1" >&2
      usage
      ;;
  esac
done

# If no --repo is provided, use the current directory
if [[ -z "${REPO_PATH}" ]]; then
  REPO_PATH=$(pwd)
fi

# Ensure repository exists
if [[ ! -d "${REPO_PATH}/.git" ]]; then
  echo "Error: ${REPO_PATH} is not a valid Git repository." >&2
  exit 1
fi

# Change to repo directory
cd "${REPO_PATH}" || exit 1

# Fetch latest changes
git fetch origin || { echo "Error: Failed to fetch updates from remote repository." >&2; exit 1; }

# Ensure the path inside the repository exists
if [[ -n "${WATCH_PATH}" && ! -d "${WATCH_PATH}" ]]; then
  echo "Error: The specified path '${WATCH_PATH}' does not exist in the repository." >&2
  exit 1
fi

# Determine commit history scope
LAST_COMMIT_FILE="${LOG_FILE}.last_commit"
LATEST_COMMIT=""
LAST_COMMIT=""

if [[ -n "${WATCH_PATH}" ]]; then
  LATEST_COMMIT=$(git log -1 --format="%H" -- "${WATCH_PATH}" || true)
else
  LATEST_COMMIT=$(git log -1 --format="%H" || true)
fi

if [[ -f "${LAST_COMMIT_FILE}" ]]; then
  LAST_COMMIT=$(cat "${LAST_COMMIT_FILE}")
fi

# If no commit is found, exit cleanly
if [[ -z "${LATEST_COMMIT}" ]]; then
  echo "No commits found in the monitored path. Exiting." >&2
  exit 0
fi

# Compare commits
if [[ "${LATEST_COMMIT}" != "${LAST_COMMIT}" ]]; then
  # Generate log output
  {
    echo "=== $(date) ==="
    case "${OUTPUT_FORMAT}" in
      text)
        git log --oneline --since="1 day ago" -- "${WATCH_PATH}"
        ;;
      diff)
        git diff HEAD^ HEAD -- "${WATCH_PATH}"
        ;;
      filename)
        git diff --name-only HEAD^ HEAD -- "${WATCH_PATH}"
        ;;
      *)
        echo "Error: Invalid output format '${OUTPUT_FORMAT}'" >&2
        exit 1
        ;;
    esac
    echo
  } >> "${LOG_FILE}"

  # Format commit details for Discord
  COMMIT_DETAILS=$(git log -1 --pretty=format:"**%an** committed: %s (%h)" -- "${WATCH_PATH}")
  case "${OUTPUT_FORMAT}" in
    text)
      CONTENT="${COMMIT_DETAILS}"
      ;;
    diff)
      CONTENT="\`\`\`\n$(git diff --stat HEAD^ HEAD -- "${WATCH_PATH}")\n\`\`\`"
      ;;
    filename)
      CONTENT="Changed files:\n\`\`\`\n$(git diff --name-only HEAD^ HEAD -- "${WATCH_PATH}")\n\`\`\`"
      ;;
  esac

  # Send Discord notification
  # shellcheck disable=SC2154 # DISCORD_WEBHOOK is loaded from ~/.env
  curl --location --request POST "${DISCORD_WEBHOOK}" \
    --header "Content-Type: application/json" \
    --data "{
      \"username\": \"Git Monitor Bot\",
      \"content\": \"🚀 **New changes detected in \`${WATCH_PATH:-entire repo}\`**\n\n📌 ${CONTENT}\"
    }"

  # Store latest commit
  echo "${LATEST_COMMIT}" > "${LAST_COMMIT_FILE}"
else
  echo "$(date): No new changes detected." >> "${LOG_FILE}"
fi
