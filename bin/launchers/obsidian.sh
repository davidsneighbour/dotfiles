#!/bin/bash
# Opens an Obsidian deep link reliably from Ubuntu custom keyboard shortcuts.

set -euo pipefail

show_help() {
  cat <<'EOF'
Usage:
  obsidian-home.sh [--vault <name>] [--file <path>] [--uri <obsidian-uri>] [--verbose]

Options:
  --vault   Vault name (default: notes)
  --file    File path inside the vault (default: Home.md)
  --uri     Full obsidian:// URI (overrides --vault/--file)
  --verbose Print debug output to stderr
  --help    Show this help
EOF
}

vault="notes"
file="Home/Home.canvas"
uri=""
verbose="false"

while [[ ${#} -gt 0 ]]; do
  case "${1}" in
    --vault)
      vault="${2:-}"; shift 2 || true
      ;;
    --file)
      file="${2:-}"; shift 2 || true
      ;;
    --uri)
      uri="${2:-}"; shift 2 || true
      ;;
    --verbose)
      verbose="true"; shift
      ;;
    --help)
      show_help; exit 0
      ;;
    *)
      echo "Error: unknown argument: ${1}" >&2
      echo >&2
      show_help
      exit 2
      ;;
  esac
done

if [[ -z "${uri}" ]]; then
  # Encode minimal characters that commonly break URI parsing.
  # (Good enough for typical vault/file names.)
  enc_vault="${vault// /%20}"
  enc_file="${file// /%20}"
  uri="obsidian://open?vault=${enc_vault}&file=${enc_file}"
fi

if [[ "${verbose}" == "true" ]]; then
  echo "URI: ${uri}" >&2
  echo "PATH: ${PATH}" >&2
fi

# Prefer xdg-open; fall back to gio.
if command -v xdg-open >/dev/null 2>&1; then
  # Run detached so the shortcut does not wait on a GUI app.
  nohup xdg-open "${uri}" >/dev/null 2>&1 & disown || true
  exit 0
fi

if command -v gio >/dev/null 2>&1; then
  nohup gio open "${uri}" >/dev/null 2>&1 & disown || true
  exit 0
fi

echo "Error: neither xdg-open nor gio found on PATH." >&2
exit 1
