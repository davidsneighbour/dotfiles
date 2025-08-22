#!/bin/bash
# bibata-build-dracula.sh
# Build a custom Bibata cursor theme with Dracula colors without touching system Python.
# Base: #ff5555, Outline: #282a36
# Requirements per upstream: clickgen>=2.1.8 (ctgen), yarn, cbmp via npx. :contentReference[oaicite:3]{index=3}

# see https://specifications.freedesktop.org/icon-theme-spec/latest/

set -euo pipefail

# ----------------------------
# Config (override via flags)
# ----------------------------
REPO_URL="https://github.com/davidsneighbour/bibata_cursor_set.git"
#REPO_URL="https://github.com/ful1e5/Bibata_Cursor.git"
REPO_DIR="${HOME}/.cache/bibata/Bibata_Cursor"
THEME_NAME="Bibata-Modern-Dracula-Red"
VARIANT="modern"                                # modern|original
BASE_COLOR="#ff5555"
OUTLINE_COLOR="#282a36"
WATCH_BG=""                                     # optional, e.g. '#1e1f29'
SIZES="24 28 32 40 48"
#INSTALL_DIR="${HOME}/.local/share/icons"
INSTALL_DIR="${HOME}/.icons"
OUT_DIR="${HOME}/.cache/bibata/out"
FORCE_CLEAN="false"
VERBOSE="false"
DRY_RUN="false"
BRANCH=""                                       # optional

# ----------------------------
# Logging helpers
# ----------------------------
log(){ printf '[%s] %s\n' "${1:-INFO}" "${2:-}"; }
run(){ [[ "${VERBOSE}" == "true" ]] && log "CMD" "$*"; [[ "${DRY_RUN}" == "true" ]] || eval "$@"; }

# ----------------------------
# Help
# ----------------------------
_help(){
  cat <<EOF
Usage: ${0##*/} [options]

Options:
  --repo-url URL            Git repo (default: ${REPO_URL})
  --repo-dir PATH           Clone dir (default: ${REPO_DIR})
  --branch NAME             Checkout branch/tag
  --variant NAME            modern|original (default: ${VARIANT})
  --theme-name NAME         Output theme name (default: ${THEME_NAME})
  --sizes "S1 S2 ..."       XCursor sizes (default: ${SIZES})
  --base-color HEX          Base color (default: ${BASE_COLOR})
  --outline-color HEX       Outline color (default: ${OUTLINE_COLOR})
  --watch-bg HEX            Optional watch background
  --install-dir PATH        Icons install dir (default: ${INSTALL_DIR})
  --force-clean             Remove generated dirs before build
  --verbose                 Verbose logging
  --dry-run                 Print actions only
  --help                    Show this help

Notes:
- PEP 668 prevents system-wide pip installs. This script uses pipx (preferred) or a local venv for clickgen/ctgen. :contentReference[oaicite:4]{index=4}
- Bibata build flow: npx cbmp (recolor) -> ctgen (build). :contentReference[oaicite:5]{index=5}
EOF
}

# ----------------------------
# Arg parsing
# ----------------------------
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --repo-url) REPO_URL="${2}"; shift 2 ;;
    --repo-dir) REPO_DIR="${2}"; shift 2 ;;
    --branch) BRANCH="${2}"; shift 2 ;;
    --variant) VARIANT="${2}"; shift 2 ;;
    --theme-name) THEME_NAME="${2}"; shift 2 ;;
    --sizes) SIZES="${2}"; shift 2 ;;
    --base-color) BASE_COLOR="${2}"; shift 2 ;;
    --outline-color) OUTLINE_COLOR="${2}"; shift 2 ;;
    --watch-bg) WATCH_BG="${2}"; shift 2 ;;
    --install-dir) INSTALL_DIR="${2}"; shift 2 ;;
    --force-clean) FORCE_CLEAN="true"; shift ;;
    --verbose) VERBOSE="true"; shift ;;
    --dry-run) DRY_RUN="true"; shift ;;
    --help) _help; exit 0 ;;
    *) log "ERROR" "Unknown option: ${1}"; _help; exit 1 ;;
  esac
done

[[ "${VARIANT}" =~ ^(modern|original)$ ]] || { log "ERROR" "Invalid --variant"; exit 1; }

SVG_DIR="svg/${VARIANT}"
BITMAP_DIR="${REPO_DIR}/bitmaps/${THEME_NAME}"

# ----------------------------
# Preflight: yarn, node, npx, pipx or venv
# ----------------------------
need(){
  if ! command -v "$1" >/dev/null 2>&1; then
    log "ERROR" "Missing dependency: $1"
    case "$1" in
      yarn)  echo "Install yarn (corepack): corepack enable && corepack prepare yarn@stable --activate" ;;
      node|npx) echo "Install Node.js 18+ (you have Node ${NODE_VERSION:-?})." ;;
      pipx)  echo "Install pipx: your distro package or 'python3 -m pip install --user pipx && python3 -m pipx ensurepath'." ;;
    esac
    exit 1
  fi
}

need node
need npx
# Yarn is used by repo scripts; we only need it for 'yarn install'.
if ! command -v yarn >/dev/null 2>&1; then
  if command -v corepack >/dev/null 2>&1; then
    run "corepack enable"
  else
    log "ERROR" "corepack/yarn required"; exit 1
  fi
fi

# ----------------------------
# Provision ctgen (clickgen) without touching system Python
# ----------------------------
CLICKGEN_BIN=""
CTGEN_BIN=""

if command -v pipx >/dev/null 2>&1; then
  # Use pipx
  if ! command -v ctgen >/dev/null 2>&1; then
    run "pipx install 'clickgen>=2.1.8'"
  fi
  CTGEN_BIN="$(command -v ctgen || true)"
else
  # Fallback to local venv
  VENV_DIR="${HOME}/.cache/bibata/venv"
  if [[ ! -f "${VENV_DIR}/bin/ctgen" ]]; then
    run "python3 -m venv '${VENV_DIR}'"
    run "'${VENV_DIR}/bin/pip' install --upgrade pip"
    run "'${VENV_DIR}/bin/pip' install 'clickgen>=2.1.8'"
  fi
  CTGEN_BIN="${VENV_DIR}/bin/ctgen"
fi

[[ -n "${CTGEN_BIN}" && -x "${CTGEN_BIN}" ]] || { log "ERROR" "ctgen not available"; exit 1; }

# ----------------------------
# Clone/update Bibata repo
# ----------------------------
if [[ -d "${REPO_DIR}/.git" ]]; then
  run "git -C '${REPO_DIR}' fetch --all --tags --prune"
  [[ -n "${BRANCH}" ]] && run "git -C '${REPO_DIR}' checkout '${BRANCH}'"
else
  run "mkdir -p '$(dirname "${REPO_DIR}")'"
  run "git clone --depth 1 '${REPO_URL}' '${REPO_DIR}'"
  [[ -n "${BRANCH}" ]] && run "git -C '${REPO_DIR}' checkout '${BRANCH}'"
fi

# Install JS deps used by the repo (yarn generate uses them). :contentReference[oaicite:6]{index=6}
run "cd '${REPO_DIR}' && yarn install --frozen-lockfile"

# Clean if requested
if [[ "${FORCE_CLEAN}" == "true" ]]; then
  run "rm -rf '${REPO_DIR}/bitmaps' '${REPO_DIR}/themes' '${OUT_DIR}'"
fi
run "mkdir -p '${OUT_DIR}'"

# ----------------------------
# 1) Render SVG -> PNG with Dracula colors via cbmp
# ----------------------------
CBMP_CMD="npx --yes cbmp -d '${SVG_DIR}' -o '${BITMAP_DIR}' -bc '${BASE_COLOR}' -oc '${OUTLINE_COLOR}'"
[[ -n "${WATCH_BG}" ]] && CBMP_CMD+=" -wc '${WATCH_BG}'"
run "cd '${REPO_DIR}' && ${CBMP_CMD}"

# ----------------------------
# 2) Build XCursors via ctgen (clickgen)
# ----------------------------
run "'${CTGEN_BIN}' '${REPO_DIR}/configs/normal/x.build.toml' -p x11 -d '${BITMAP_DIR}' -n '${THEME_NAME}' -c 'Dracula Bibata (${BASE_COLOR} on ${OUTLINE_COLOR})' -s ${SIZES}"

# ----------------------------
# 2.5) Fix preview metadata and default symlink
# ----------------------------
INDEX_THEME="${REPO_DIR}/themes/${THEME_NAME}/index.theme"
CURSORS_DIR="${REPO_DIR}/themes/${THEME_NAME}/cursors"

# Ensure Example=left_ptr exists for previewers
if [[ -f "${INDEX_THEME}" ]]; then
  if ! grep -q '^Example=' "${INDEX_THEME}"; then
    # Add after [Icon Theme] header or append at end as fallback
    if grep -q '^\[Icon Theme\]' "${INDEX_THEME}"; then
      awk '1; /^\[Icon Theme\]$/ && !x {print "Example=left_ptr"; x=1}' "${INDEX_THEME}" > "${INDEX_THEME}.tmp" \
        && mv "${INDEX_THEME}.tmp" "${INDEX_THEME}"
    else
      printf '\n[Icon Theme]\nExample=left_ptr\n' >> "${INDEX_THEME}"
    fi
  fi
fi

# Ensure default -> left_ptr symlink exists (helps some environments)
if [[ -d "${CURSORS_DIR}" ]]; then
  if [[ ! -e "${CURSORS_DIR}/default" ]]; then
    ln -s left_ptr "${CURSORS_DIR}/default"
  fi
fi

# ----------------------------
# Install to user icons dir
# ----------------------------
THEME_SRC="${REPO_DIR}/themes/${THEME_NAME}"
[[ -d "${THEME_SRC}" ]] || { log "ERROR" "Theme not found: ${THEME_SRC}"; exit 1; }
run "mkdir -p '${INSTALL_DIR}'"
run "cp -a '${THEME_SRC}' '${INSTALL_DIR}/'"

log "INFO" "Installed: ${INSTALL_DIR}/${THEME_NAME}"
log "INFO" "Select it in your cursor settings."
