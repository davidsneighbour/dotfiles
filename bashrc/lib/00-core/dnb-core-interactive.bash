# shellcheck shell=bash

# dnb_is_interactive
#
# Return success when the shell should be treated as interactive.
#
# Parameters:
#   none
#
# Behaviour:
#   - Returns 0 when DNB_IS_INTERACTIVE=1.
#   - Returns 1 otherwise.
#
# Examples:
#   if dnb_is_interactive; then
#     dnb_log info "Interactive mode enabled"
#   fi
#
# Requirements:
#   - bash

dnb_is_interactive() {
  [[ "${DNB_IS_INTERACTIVE:-0}" == "1" ]]
}

dnb_log_header() {
  # Displays the dotfiles header using the version from DOTFILES_PATH/package.json.
  #
  # Requirements:
  # - DOTFILES_PATH must point to the dotfiles repository root.
  # - package.json must exist at "${DOTFILES_PATH}/package.json".
  # - node must be available.
  # - gum must be available.

  local package_json
  local version

  if [[ -z "${DOTFILES_PATH:-}" ]]; then
    echo "[error] DOTFILES_PATH is not set." >&2
    return 1
  fi

  package_json="${DOTFILES_PATH}/package.json"

  if [[ ! -f "${package_json}" ]]; then
    echo "[error] Missing package.json: ${package_json}" >&2
    return 1
  fi

  version="$(
    # shellcheck disable=SC2016  # we don't need to expand here
    node --input-type=module -e '
      import { readFileSync } from "node:fs";
      const packageJsonPath = process.argv[1];
      try {
        const data = JSON.parse(readFileSync(packageJsonPath, "utf8"));
        if (typeof data.version !== "string" || data.version.trim() === "") {
          throw new Error("package.json does not contain a valid version string.");
        }
        console.log(data.version);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.error(`[error] Failed to read version from package.json: ${message}`);
        process.exit(1);
      }
    ' "${package_json}"
  )" || return 1

  gum style \
    --foreground 216 \
    --border-foreground 66 \
    --border double \
    --align center \
    --width 80 \
    --padding "0 1" \
    "@davidsneighbour's DotFiles" \
    "v${version}"
}
