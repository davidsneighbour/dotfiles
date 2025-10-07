#!/bin/bash
# install-obsidian-latest.sh
# Download and install the latest amd64 .deb from obsidianmd/obsidian-releases.
# Requirements: curl, dpkg, sudo. Optional: jq (any version).
# ShellCheck-compliant.

set -euo pipefail

API_URL="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
DOWNLOAD_DIR="/tmp"
INSTALL="yes"
KEEP_FILE="no"
QUIET="no"
VERBOSE=0
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

log() {
  local level="${1:-info}"; shift || true
  local msg="${*:-}"
  if [[ "${QUIET}" == "yes" && "${level}" != "error" ]]; then return 0; fi
  case "${level}" in
    error) printf "[%s][error] %s\n" "$(date +'%F %T')" "${msg}" >&2 ;;
    warn)  printf "[%s][warn]  %s\n" "$(date +'%F %T')" "${msg}" ;;
    info)  [[ "${VERBOSE}" -ge 0 ]] && printf "[%s][info]  %s\n" "$(date +'%F %T')" "${msg}" ;;
    debug) [[ "${VERBOSE}" -ge 1 ]] && printf "[%s][debug] %s\n" "$(date +'%F %T')" "${msg}" ;;
    trace) [[ "${VERBOSE}" -ge 2 ]] && printf "[%s][trace] %s\n" "$(date +'%F %T')" "${msg}" ;;
    *)     printf "[%s][info]  %s\n" "$(date +'%F %T')" "${msg}" ;;
  esac
}

usage() {
  cat <<EOF
$(basename "$0") -- download and install the latest Obsidian amd64 .deb

Usage:
  $(basename "$0") [--download-dir=PATH] [--no-install] [--keep] [-v|-vv] [-q] [--help]

Options:
  --download-dir=PATH   Directory to place the downloaded .deb (default: ${DOWNLOAD_DIR})
  --no-install          Download only, do not install via dpkg
  --keep                Do not delete the downloaded file after successful install
  -v                    Verbose output (debug)
  -vv                   Very verbose output (trace)
  -q                    Quiet mode (only errors)
  --help                Show this help

Environment:
  GITHUB_TOKEN          Optional. Used to authenticate to GitHub API to avoid rate limits.
EOF
}

require_cmd() {
  local cmd="${1:?missing command name}"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    log error "Required command not found: ${cmd}"
    exit 127
  fi
}

fetch_latest_release_json() {
  # Return raw JSON on stdout
  local headers
  headers=(-H "Accept: application/vnd.github+json" -H "User-Agent: obsidian-installer")
  if [[ -n "${GITHUB_TOKEN}" ]]; then
    headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  curl -fsSL "${headers[@]}" "${API_URL}"
}

# Robust jq filter (works on jq 1.5+). No MIME filtering.
# Pick the FIRST asset whose name OR URL ends with 'amd64.deb' (case-insensitive).
jq_filter_asset_url='
  [
    .assets[]
    | {
        name: (.name // ""),
        url:  (.browser_download_url // "")
      }
    | select(
        (.name | ascii_downcase | endswith("amd64.deb")) or
        (.url  | ascii_downcase | endswith("amd64.deb"))
      )
  ][0].url
'

clean_json() {
  # Strip CRs and NULs that can upset jq; keep one line to avoid tty wrapping
  tr -d '\r\000'
}

extract_asset_url_with_jq() {
  # Works on jq 1.5+; match name or URL that ends with amd64.deb (case-insensitive)
  jq -r '
    .assets
    | map({name: (.name // ""), url: (.browser_download_url // "")})
    | map(select(
        (.name|ascii_downcase|endswith("amd64.deb")) or
        (.url |ascii_downcase|endswith("amd64.deb"))
      ))
    | .[0].url // empty
  '
}

extract_asset_url_fallback() {
  # Robust grep fallback: take first browser_download_url ending with amd64.deb
  grep -oE '"browser_download_url"\s*:\s*"[^"]+amd64\.deb"' \
    | sed -E 's/.*:\s*"([^"]+)".*/\1/' \
    | head -n 1
}

pick_filename_from_url() {
  local url="${1:?url required}"
  basename "${url%$'\r'}"
}

install_deb() {
  local deb_path="${1:?deb path required}"
  log info "Installing: ${deb_path} (sudo dpkg -i)"
  if ! sudo dpkg -i "${deb_path}"; then
    log warn "dpkg reported missing dependencies, attempting: sudo apt-get -y -f install"
    sudo apt-get -y -f install
    sudo dpkg -i "${deb_path}"
  fi
  log info "Installation completed."
}

main() {
  for arg in "$@"; do
    case "${arg}" in
      --download-dir=*) DOWNLOAD_DIR="${arg#*=}";;
      --no-install)     INSTALL="no";;
      --keep)           KEEP_FILE="yes";;
      -vv)              VERBOSE=2;;
      -v)               VERBOSE=1;;
      -q)               QUIET="yes";;
      --help)           usage; exit 0;;
      *)                log error "Unknown argument: ${arg}"; usage; exit 2;;
    esac
  done

  require_cmd curl
  require_cmd dpkg
  require_cmd sudo
  mkdir -p "${DOWNLOAD_DIR}"

  log info "Querying GitHub for latest Obsidian release metadata"
# Fetch
release_json="$(fetch_latest_release_json)"

# Optional API error (only if jq exists and parses)
if command -v jq >/dev/null 2>&1; then
  if msg="$(printf '%s' "${release_json}" | clean_json | jq -r '.message // empty' 2>/dev/null)"; [[ -n "${msg}" ]]; then
    log error "GitHub API error: ${msg}"
    log error "Tip: export GITHUB_TOKEN to avoid rate limits."
    exit 1
  fi
fi

# Extract URL (jq first, then fallback)
asset_url=""
if command -v jq >/dev/null 2>&1; then
  asset_url="$(printf '%s' "${release_json}" | clean_json | extract_asset_url_with_jq || true)"
fi
if [[ -z "${asset_url}" ]]; then
  asset_url="$(printf '%s' "${release_json}" | clean_json | extract_asset_url_fallback || true)"
fi

if [[ -z "${asset_url}" ]]; then
  log warn "amd64 .deb asset not located via primary and fallback matchers."
  if [[ "${VERBOSE}" -ge 1 ]] && command -v jq >/dev/null 2>&1; then
    log debug "Asset inventory (name | url):"
    printf '%s' "${release_json}" | clean_json | jq -r '.assets[] | "\(.name) | \(.browser_download_url)"' || true
  fi
  log error "Could not find an amd64 .deb asset in the latest release."
  exit 1
fi

log info "Found asset: ${asset_url}"
  filename="$(pick_filename_from_url "${asset_url}")"
  filepath="${DOWNLOAD_DIR%/}/${filename}"

  log info "Downloading to: ${filepath}"
  if [[ -n "${GITHUB_TOKEN}" ]]; then
    curl -fL --retry 3 --retry-delay 2 -H "Authorization: Bearer ${GITHUB_TOKEN}" -o "${filepath}" "${asset_url}"
  else
    curl -fL --retry 3 --retry-delay 2 -o "${filepath}" "${asset_url}"
  fi
  log info "Download complete."

  if [[ "${INSTALL}" == "yes" ]]; then
    install_deb "${filepath}"
    if [[ "${KEEP_FILE}" == "no" ]]; then
      log debug "Removing downloaded file: ${filepath}"
      rm -f -- "${filepath}"
    else
      log debug "Keeping downloaded file as requested."
    fi
  else
    log info "Skipping install as requested. File saved at: ${filepath}"
  fi

  log info "Done."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
