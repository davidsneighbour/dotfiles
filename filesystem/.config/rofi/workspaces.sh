#!/bin/bash

set -euo pipefail  # Exit on error, undefined var, or pipe failure

# Manual logging
LOGFILE="${HOME}/.logs/rofi.log"
mkdir -p "$(dirname "$LOGFILE")"
log() {
  local level=$1; shift
  printf "[%s][rofi][%s] %s\n" \
    "$(date +'%Y-%m-%d %H:%M:%S')" "$level" "$*" \
    >> "$LOGFILE"
}

log info "Starting rofi project selector"
log debug "PATH=${PATH}"

# Ensure 'code' CLI is available
if ! command -v code &>/dev/null; then
  log error "'code' not found in PATH"
  exit 1
fi

# Default configurations
WORKINGDIR="${HOME}/.config/rofi/"
PROJECTS_DIRS=("${HOME}/github.com/davidsneighbour")
WORKSPACE_FILES_DIRS=()
FILE_PATTERN="*.code-workspace"
ROFI_CONFIG="${WORKINGDIR}/config.rasi"
PROMPT="Select Project"
SORT_ORDER="ASC"
CREATE_WORKSPACE="false"
CACHE_FILE="${HOME}/.cache/rofi_workspaces_cache"
CACHE_SIZE=5
HIDE_EMPTY_PROJECTS="false"
NEW_WINDOW="false"

# Helpers
resolve_dir() {
  local input="${1:-}"
  local resolved=""

  [[ -z "${input}" ]] && return 1

  case "${input}" in
    # absolute
    /*) resolved="${input}" ;;
    # tilde
    ~)  resolved="${HOME}" ;;
    ~/*) resolved="${HOME}/${input#~/}" ;;
    # $HOME shortcuts often used in your setup
    .dotfiles/*|github.com/*|gitlab.com/*)
        resolved="${HOME}/${input}" ;;
    # explicit relative
    ./*|../*)
        resolved="${PWD}/${input#./}" ;;
    # bare segment: try CWD, then $HOME
    *)
        if [[ -d "${PWD}/${input}" ]]; then
          resolved="${PWD}/${input}"
        elif [[ -d "${HOME}/${input}" ]]; then
          resolved="${HOME}/${input}"
        else
          return 1
        fi
        ;;
  esac

  [[ -d "${resolved}" ]] || return 1
  printf '%s\n' "${resolved}"
}

sanitize_project_dirs() {
  local out=() d r
  for d in "$@"; do
    if r="$(resolve_dir "${d}")"; then
      out+=("${r}")
    else
      log warn "Skipping invalid project directory '${d}'"
    fi
  done
  ((${#out[@]})) && printf '%s\n' "${out[@]}"
}

update_cache() {
  local sel=$1
  log debug "Updating cache with '$sel'"
  mkdir -p "$(dirname "$CACHE_FILE")"
  if [[ -f "$CACHE_FILE" ]]; then
    grep -v -x "$sel" "$CACHE_FILE" > "${CACHE_FILE}.tmp" || true
    mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
  fi
  echo "$sel" >> "$CACHE_FILE"
  tail -n "$CACHE_SIZE" "$CACHE_FILE" > "${CACHE_FILE}.tmp"
  mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
}

# Parse --clearcache first
if [[ "$*" == *--clearcache* ]]; then
  if [[ "$#" -ne 1 ]]; then
    log error "--clearcache must be used alone"
    exit 1
  fi
  rm -f "$CACHE_FILE"
  log info "Cache cleared"
  exit 0
fi

# Argument parsing
while [[ $# -gt 0 ]]; do
  case $1 in
    --workingdir)
      WORKINGDIR="$2"; shift 2 ;;
    --projectsdirs)
      IFS=',' read -r -a raw <<< "$2"
      mapfile -t PROJECTS_DIRS < <(sanitize_project_dirs "${raw[@]}")
      shift 2 ;;
    --workspacedirs)
      IFS=',' read -r -a raw <<< "$2"
      mapfile -t WORKSPACE_FILES_DIRS < <(sanitize_project_dirs "${raw[@]}")
      shift 2 ;;
    --filepattern)
      FILE_PATTERN="$2"; shift 2 ;;
    --config)
      ROFI_CONFIG="$2"; shift 2 ;;
    --prompt)
      PROMPT="$2"; shift 2 ;;
    --sortorder)
      SORT_ORDER="$2"; shift 2 ;;
    --createworkspace)
      CREATE_WORKSPACE="true"; shift ;;
    --hideemptyprojects)
      HIDE_EMPTY_PROJECTS="true"; shift ;;
    --newwindow)
      NEW_WINDOW="true"; shift ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]
Options:
  --clearcache             Clear the selection cache (alone)
  --workingdir DIR         Rofi config dir (default: $WORKINGDIR)
  --projectsdirs DIRS      Comma-separated project base dirs
  --workspacedirs DIRS     Comma-separated workspace-file dirs
  --filepattern PATTERN    Glob for .code-workspace (default: $FILE_PATTERN)
  --config FILE            Rofi config (default: $ROFI_CONFIG)
  --prompt TEXT            Prompt text (default: '$PROMPT')
  --sortorder ASC|DESC     Sort order (default: $SORT_ORDER)
  --createworkspace        Create .code-workspace if missing
  --hideemptyprojects      Skip projects without .code-workspace
  --newwindow              Open in new VS Code window
  --help                   Show this message
EOF
      exit 0 ;;
    *)
      log error "Unknown option: $1"
      exit 1 ;;
  esac
done

log debug "Parsed options: WORKINGDIR=${WORKINGDIR}, SORT_ORDER=${SORT_ORDER}, CREATE_WORKSPACE=${CREATE_WORKSPACE}, HIDE_EMPTY_PROJECTS=${HIDE_EMPTY_PROJECTS}, NEW_WINDOW=${NEW_WINDOW}"

# Log resolved directories for debugging
if (( ${#PROJECTS_DIRS[@]} > 0 )); then
  log debug "Resolved PROJECTS_DIRS:"
  for d in "${PROJECTS_DIRS[@]}"; do log debug "  - ${d}"; done
fi

if (( ${#WORKSPACE_FILES_DIRS[@]} > 0 )); then
  log debug "Resolved WORKSPACE_FILES_DIRS:"
  for d in "${WORKSPACE_FILES_DIRS[@]}"; do log debug "  - ${d}"; done
fi

# Determine VS Code command
if [[ "$NEW_WINDOW" == "true" ]]; then
  CODE_COMMAND=(code)
else
  CODE_COMMAND=(code -r)
fi
log debug "Using CODE_COMMAND='${CODE_COMMAND[*]}'"

# Collect project directories
PROJECT_DIRS=()
for base in "${PROJECTS_DIRS[@]}"; do
  mapfile -t tmp < <(find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  PROJECT_DIRS+=("${tmp[@]}")
done
log info "Found ${#PROJECT_DIRS[@]} project directories"

# Collect workspace files (from explicit dirs)
WORKSPACE_FILES=()
if ((${#WORKSPACE_FILES_DIRS[@]})); then
  for d in "${WORKSPACE_FILES_DIRS[@]}"; do
    log debug "Scanning workspace dir: ${d}"
    while IFS= read -r -d '' f; do
      WORKSPACE_FILES+=("${f}")
    done < <(find "${d}" -type f -name "${FILE_PATTERN}" -print0 2>/dev/null || true)
  done
else
  # Optional fallback: if a common default exists, use it
  if [[ -d "${HOME}/.dotfiles/configs/workspaces" ]]; then
    log warn "No --workspacedirs provided; falling back to ${HOME}/.dotfiles/configs/workspaces"
    WORKSPACE_FILES_DIRS=("${HOME}/.dotfiles/configs/workspaces")
    while IFS= read -r -d '' f; do
      WORKSPACE_FILES+=("${f}")
    done < <(find "${WORKSPACE_FILES_DIRS[0]}" -type f -name "${FILE_PATTERN}" -print0 2>/dev/null || true)
  else
    log debug "No WORKSPACE_FILES_DIRS provided"
  fi
fi
log info "Found ${#WORKSPACE_FILES[@]} workspace files"

if (( ${#WORKSPACE_FILES_DIRS[@]} > 0 )) && (( ${#WORKSPACE_FILES[@]} == 0 )); then
  log warn "No *.code-workspace files found in provided --workspacedirs"
fi

# Map names to paths
declare -A PROJECT_MAP WORKSPACE_MAP
for d in "${PROJECT_DIRS[@]}"; do
  PROJECT_MAP["$(basename "$d")"]="$d"
done
for f in "${WORKSPACE_FILES[@]}"; do
  nm=$(basename "$f" .code-workspace)
  [[ -z $nm ]] && nm=$(basename "$(dirname "$f")")
  WORKSPACE_MAP["$nm"]="$f"
done

# Load cache
CACHED=()
if [[ -f "$CACHE_FILE" ]]; then
  mapfile -t CACHED < <(tac "$CACHE_FILE")
  log debug "Loaded cache: ${CACHED[*]}"
else
  log debug "No cache file found"
fi

# Build display entries with Pango markup
declare -A DISPLAY_TO_TARGET DISPLAY_TO_NAME
MENU_ENTRIES=()

build_entry() {
  local name=$1 type=$2 path=$3 short
  if [[ "$type" == "workspace" ]]; then
    short="workspace"
  else
    short=${path/#$HOME\//~\/}
  fi
  printf "<span weight='bold'>%s</span> <span color='#888888' size='small'>(%s)</span>" \
    "$name" "$short"
}

# 1) cached first
for name in "${CACHED[@]}"; do
  if [[ -n "${WORKSPACE_MAP[$name]:-}" ]]; then
    target=${WORKSPACE_MAP[$name]}; type="workspace"
  elif [[ -n "${PROJECT_MAP[$name]:-}" ]]; then
    target=${PROJECT_MAP[$name]}; type="project"
  else
    continue
  fi
  entry=$(build_entry "$name" "$type" "$target")
  DISPLAY_TO_TARGET["$entry"]=$target
  DISPLAY_TO_NAME["$entry"]=$name
  MENU_ENTRIES+=("$entry")
done

# 2) remaining workspaces + projects
NAMES=()
for name in "${!WORKSPACE_MAP[@]}"; do
  [[ " ${CACHED[*]} " == *" $name "* ]] && continue
  NAMES+=("$name")
done
for name in "${!PROJECT_MAP[@]}"; do
  [[ " ${CACHED[*]} " == *" $name "* ]] && continue
  if [[ "$HIDE_EMPTY_PROJECTS" == "true" ]]; then
    [[ -z $(find "${PROJECT_MAP[$name]}" -mindepth 1 -maxdepth 1 -type f -name "$FILE_PATTERN" | head -n1) ]] && continue
  fi
  NAMES+=("$name")
done

# sort names
if [[ "$SORT_ORDER" == "ASC" ]]; then
  IFS=$'\n' sorted=($(sort <<<"${NAMES[*]}")); unset IFS
else
  IFS=$'\n' sorted=($(sort -r <<<"${NAMES[*]}")); unset IFS
fi

for name in "${sorted[@]}"; do
  if [[ -n "${WORKSPACE_MAP[$name]:-}" ]]; then
    target=${WORKSPACE_MAP[$name]}; type="workspace"
  else
    target=${PROJECT_MAP[$name]}; type="project"
  fi
  entry=$(build_entry "$name" "$type" "$target")
  DISPLAY_TO_TARGET["$entry"]=$target
  DISPLAY_TO_NAME["$entry"]=$name
  MENU_ENTRIES+=("$entry")
done

log debug "Resolved PROJECTS_DIRS:"
for d in "${PROJECTS_DIRS[@]}"; do log debug "  - ${d}"; done || true

log debug "Resolved WORKSPACE_FILES_DIRS:"
for d in "${WORKSPACE_FILES_DIRS[@]}"; do log debug "  - ${d}"; done || true

# Launch rofi with markup (config.rasi must have markup-rows: true)
PROMPT="${PROMPT} (${#MENU_ENTRIES[@]} available)"
log debug "Launching rofi"
SELECTED=$(printf '%s\n' "${MENU_ENTRIES[@]}" \
  | rofi -dmenu -i -markup-rows -config "${ROFI_CONFIG}" -p "${PROMPT}")
if [[ -z "$SELECTED" ]]; then
  log info "No selection, exiting"
  exit 1
fi

# Resolve and log selection
sel_name=${DISPLAY_TO_NAME[$SELECTED]}
sel_target=${DISPLAY_TO_TARGET[$SELECTED]}
log info "User selected '$sel_name' → '$sel_target'"
update_cache "$sel_name"

# Open in VS Code
if [[ -d "$sel_target" ]]; then
  wsf=$(find "$sel_target" -mindepth 1 -maxdepth 1 -type f -name "$FILE_PATTERN" | head -n1)
  if [[ -n "$wsf" ]]; then
    "${CODE_COMMAND[@]}" "$wsf"
  elif [[ "$CREATE_WORKSPACE" == "true" ]]; then
    tpl="${WORKINGDIR}/workspace.code-workspace"
    new="${sel_target}/workspace.code-workspace"
    if [[ -f "$tpl" ]]; then
      cp "$tpl" "$new"
    else
      cat > "$new" <<EOL
{
  "folders":[{"path":"."}]
}
EOL
    fi
    log info "Created workspace: $new"
    "${CODE_COMMAND[@]}" "$new"
  else
    "${CODE_COMMAND[@]}" "$sel_target"
  fi
else
  "${CODE_COMMAND[@]}" "$sel_target"
fi

exit 0
