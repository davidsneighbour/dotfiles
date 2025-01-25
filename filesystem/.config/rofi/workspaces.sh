#!/bin/bash

set -euo pipefail  # Robust script options

# Default configurations
WORKINGDIR="${HOME}/.config/rofi/"  # Directory containing rofi configuration
PROJECTS_DIRS=("${HOME}/github.com/davidsneighbour")  # Array of base directories for projects
WORKSPACE_FILES_DIRS=()  # Directories containing individual .code-workspace files
FILE_PATTERN="*.code-workspace"  # File pattern to search for
ROFI_CONFIG="${WORKINGDIR}/config.rasi"  # Rofi configuration file
PROMPT="Select Project"  # Rofi prompt text
SORT_ORDER="ASC"  # Sorting order for the rofi menu (default: ASC)
CREATE_WORKSPACE="false"  # Whether to create a workspace file if none exists
CACHE_FILE="${HOME}/.cache/rofi_workspaces_cache"  # Cache file to store last selected items
CACHE_SIZE=5  # Number of items to keep in the cache
HIDE_EMPTY_PROJECTS="false"  # Hide project directories with no .code-workspace files
NEW_WINDOW="false"  # Whether to open a new Visual Studio Code window

# Ensure required directories exist
if [[ ! -d "${WORKINGDIR}" ]]; then
  echo "Error: Working directory '${WORKINGDIR}' does not exist." >&2
  exit 1
fi

# Sanitize project directories
sanitize_project_dirs() {
  local dirs=()
  for dir in "$@"; do
    if [[ -d "${dir}" ]]; then
      dirs+=("${dir}")
    elif [[ -d "${HOME}/${dir}" ]]; then
      dirs+=("${HOME}/${dir}")
    else
      echo "Warning: Skipping invalid project directory '${dir}'" >&2
    fi
  done
  printf '%s\n' "${dirs[@]}"
}

# Update cache with the selected project
update_cache() {
  local selected="$1"
  if [[ -f "${CACHE_FILE}" ]]; then
    # Remove selected project if already in cache
    grep -v -x "${selected}" "${CACHE_FILE}" > "${CACHE_FILE}.tmp" || true
    mv "${CACHE_FILE}.tmp" "${CACHE_FILE}"
  fi
  # Add to the top of the cache
  echo "${selected}" >> "${CACHE_FILE}"
  # Trim cache size
  tail -n "${CACHE_SIZE}" "${CACHE_FILE}" > "${CACHE_FILE}.tmp"
  mv "${CACHE_FILE}.tmp" "${CACHE_FILE}"
}

# Parse arguments
if [[ "$*" == *--clearcache* ]]; then
  if [[ "$#" -ne 1 ]]; then
    echo "Error: --clearcache must be used alone without any other parameters." >&2
    exit 1
  fi
  rm -f "${CACHE_FILE}"
  echo "Cache cleared."
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workingdir)
      WORKINGDIR="$2"
      shift 2
      ;;
    --projectsdirs)
      IFS=',' read -r -a raw_dirs <<< "$2"
      mapfile -t PROJECTS_DIRS < <(sanitize_project_dirs "${raw_dirs[@]}")
      shift 2
      ;;
    --workspacedirs)
      IFS=',' read -r -a raw_dirs <<< "$2"
      mapfile -t WORKSPACE_FILES_DIRS < <(sanitize_project_dirs "${raw_dirs[@]}")
      shift 2
      ;;
    --filepattern)
      FILE_PATTERN="$2"
      shift 2
      ;;
    --config)
      ROFI_CONFIG="$2"
      shift 2
      ;;
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --sortorder)
      SORT_ORDER="$2"
      shift 2
      ;;
    --createworkspace)
      CREATE_WORKSPACE="true"
      shift
      ;;
    --hideemptyprojects)
      HIDE_EMPTY_PROJECTS="true"
      shift
      ;;
    --newwindow)
      NEW_WINDOW="true"
      shift
      ;;
    --help)
      echo "Usage: ${FUNCNAME[0]} [OPTIONS]"
      echo "Generates a rofi menu for opening projects or workspace files."
      echo
      echo "Options:"
      echo "  --workingdir DIR      Set the rofi working directory (default: ${WORKINGDIR})"
      echo "  --projectsdirs DIRS   Set the projects directories as a comma-separated list (default: ${PROJECTS_DIRS[*]})"
      echo "  --workspacedirs DIRS  Set directories containing individual .code-workspace files (default: none)"
      echo "  --filepattern PATTERN Set the workspace file pattern (default: ${FILE_PATTERN})"
      echo "  --config FILE         Set the rofi configuration file (default: ${ROFI_CONFIG})"
      echo "  --prompt TEXT         Set the rofi prompt text (default: '${PROMPT}')"
      echo "  --sortorder ORDER     Set the sorting order (ASC or DESC, default: ${SORT_ORDER})"
      echo "  --createworkspace     Enable creation of workspace files if none exist (default: ${CREATE_WORKSPACE})"
      echo "  --hideemptyprojects   Hide project directories without .code-workspace files (default: ${HIDE_EMPTY_PROJECTS})"
      echo "  --newwindow           Open workspace in a new Visual Studio Code window."
      echo "  --clearcache          Clear the cache file. Must be used alone."
      echo "  --help                Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Determine the Visual Studio Code command based on the --newwindow flag
CODE_COMMAND="code"
if [[ "${NEW_WINDOW}" == "false" ]]; then
  CODE_COMMAND="code -r"
fi

# List all directories in the projects directories
PROJECT_DIRS=()
for BASE_DIR in "${PROJECTS_DIRS[@]}"; do
  mapfile -t FOUND_DIRS < <(find "${BASE_DIR}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  PROJECT_DIRS+=("${FOUND_DIRS[@]}")
done

if [[ ${#PROJECT_DIRS[@]} -eq 0 && ${#WORKSPACE_FILES_DIRS[@]} -eq 0 ]]; then
  echo "No projects or workspace files found in specified directories." >&2
  exit 1
fi

# Generate menu options (folder names and workspace files)
MENU_OPTIONS=()
if [[ -f "${CACHE_FILE}" ]]; then
  mapfile -t MENU_OPTIONS < "${CACHE_FILE}"
fi

# Add individual workspace files to the menu first
WORKSPACE_ITEMS=()
declare -A WORKSPACE_FILES_MAP
for DIR in "${WORKSPACE_FILES_DIRS[@]}"; do
  while IFS= read -r -d '' WORKSPACE_FILE; do
    WORKSPACE_NAME=$(basename "${WORKSPACE_FILE}" .code-workspace)
    if [[ -z "${WORKSPACE_NAME}" ]]; then
      WORKSPACE_NAME=$(basename "$(dirname "${WORKSPACE_FILE}")")
    fi
    WORKSPACE_FILES_MAP["${WORKSPACE_NAME}"]="${WORKSPACE_FILE}"
    if ! printf '%s\n' "${MENU_OPTIONS[@]}" | grep -qx "${WORKSPACE_NAME}"; then
      WORKSPACE_ITEMS+=("${WORKSPACE_NAME}")
    fi
  done < <(find "${DIR}" -type f -name "${FILE_PATTERN}" -print0)
done

# Sort workspace items
if [[ "${SORT_ORDER}" == "ASC" ]]; then
  mapfile -t WORKSPACE_ITEMS < <(printf '%s\n' "${WORKSPACE_ITEMS[@]}" | sort)
elif [[ "${SORT_ORDER}" == "DESC" ]]; then
  mapfile -t WORKSPACE_ITEMS < <(printf '%s\n' "${WORKSPACE_ITEMS[@]}" | sort -r)
fi

# Add workspace items to the final menu options
MENU_OPTIONS+=("${WORKSPACE_ITEMS[@]}")

# Add project directories to the menu
PROJECT_ITEMS=()
for DIR in "${PROJECT_DIRS[@]}"; do
  if [[ "${HIDE_EMPTY_PROJECTS}" == "true" ]]; then
    WORKSPACE_FILE=$(find "${DIR}" -mindepth 1 -maxdepth 1 -type f -name "${FILE_PATTERN}" | head -n 1)
    if [[ -z "${WORKSPACE_FILE}" ]]; then
      continue
    fi
  fi
  PROJECT_NAME=$(basename "${DIR}")
  if ! printf '%s\n' "${MENU_OPTIONS[@]}" | grep -qx "${PROJECT_NAME}"; then
    PROJECT_ITEMS+=("${PROJECT_NAME}")
  fi
done

# Sort project directory items
if [[ "${SORT_ORDER}" == "ASC" ]]; then
  mapfile -t PROJECT_ITEMS < <(printf '%s\n' "${PROJECT_ITEMS[@]}" | sort)
elif [[ "${SORT_ORDER}" == "DESC" ]]; then
  mapfile -t PROJECT_ITEMS < <(printf '%s\n' "${PROJECT_ITEMS[@]}" | sort -r)
fi

# Add project items to the final menu options
MENU_OPTIONS+=("${PROJECT_ITEMS[@]}")

# Update prompt dynamically
PROMPT="${PROMPT} (${#MENU_OPTIONS[@]} available)"

# Display rofi menu
SELECTED_PROJECT=$(printf '%s\n' "${MENU_OPTIONS[@]}" | rofi -dmenu -i -config "${ROFI_CONFIG}" -p "${PROMPT}")

# Validate selection
if [[ -z "${SELECTED_PROJECT}" ]]; then
  echo "No project selected." >&2
  exit 1
fi

# Determine the selected project directory or workspace file
SELECTED_PROJECT_DIR=""
SELECTED_WORKSPACE_FILE=""

if [[ -n "${WORKSPACE_FILES_MAP[${SELECTED_PROJECT}]:-}" ]]; then
  SELECTED_WORKSPACE_FILE="${WORKSPACE_FILES_MAP[${SELECTED_PROJECT}]}"
else
  for DIR in "${PROJECT_DIRS[@]}"; do
    if [[ "$(basename "${DIR}")" == "${SELECTED_PROJECT}" ]]; then
      SELECTED_PROJECT_DIR="${DIR}"
      break
    fi
  done
fi

if [[ -n "${SELECTED_WORKSPACE_FILE}" ]]; then
  # Open the selected workspace file
  ${CODE_COMMAND} "${SELECTED_WORKSPACE_FILE}"
elif [[ -n "${SELECTED_PROJECT_DIR}" ]]; then
  # Check if a workspace file exists in the selected directory
  WORKSPACE_FILE=$(find "${SELECTED_PROJECT_DIR}" -mindepth 1 -maxdepth 1 -type f -name "${FILE_PATTERN}" | head -n 1)

  if [[ -n "${WORKSPACE_FILE}" ]]; then
    # Open the workspace file if it exists
    ${CODE_COMMAND} "${WORKSPACE_FILE}"
  else
    if [[ "${CREATE_WORKSPACE}" == "true" ]]; then
      # Create a workspace file if it doesn't exist
      TEMPLATE_FILE="${WORKINGDIR}/workspace.code-workspace"
      NEW_WORKSPACE_FILE="${SELECTED_PROJECT_DIR}/workspace.code-workspace"

      if [[ -f "${TEMPLATE_FILE}" ]]; then
        cp "${TEMPLATE_FILE}" "${NEW_WORKSPACE_FILE}"
      else
        # Fallback template if no template file is available
        cat > "${NEW_WORKSPACE_FILE}" <<EOL
{
  "folders": [
    {
      "path": "."
    }
  ]
}
EOL
      fi

      echo "Created new workspace file: ${NEW_WORKSPACE_FILE}"
      ${CODE_COMMAND} "${NEW_WORKSPACE_FILE}"
    else
      # Open the project directory if no workspace file is found
      ${CODE_COMMAND} "${SELECTED_PROJECT_DIR}"
    fi
  fi
else
  echo "Error: Could not determine the selection." >&2
  exit 1
fi

exit 0
