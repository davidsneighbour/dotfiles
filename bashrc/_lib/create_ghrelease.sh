# shellcheck shell=bash

# create a GitHub release
# Uses the GITHUB_SECRET and GITHUB_REPOSLUG environment variables
# @param $1 (optional) Version string (e.g., "1.0.0"). If not provided, extracts the version from package.json.
create_ghrelease() {
  local version="${1:-}"
  local tagname

  # Extract version from package.json if not provided
  if [ -z "$version" ]; then
    if [ -f "./package.json" ]; then
      version=$(node -pe 'require("./package.json")["version"]')
      if [ -z "$version" ]; then
        echo "Error: Could not extract version from package.json."
        return 1
      fi
    else
      echo "Error: package.json not found, and no version provided."
      return 1
    fi
  fi

  # Construct the tag name
  tagname="v${version}"

  # Ensure required environment variables are set
  : "${GITHUB_SECRET:?Environment variable GITHUB_SECRET is not set.}"
  : "${GITHUB_REPOSLUG:?Environment variable GITHUB_REPOSLUG is not set.}"

  # GitHub repository URL
  local github_repo="https://github.com/${GITHUB_REPOSLUG}"
  local release_url="${github_repo}/releases/edit/${tagname}"

  # Open the release for editing, if possible
  if command -v xdg-open >/dev/null; then
    xdg-open "${release_url}" &>/dev/null || {
      echo "Warning: Failed to open browser for release editing."
      echo "Manual action required: Open ${release_url} to edit the release."
    }
  else
    echo "Manual action required: Open ${release_url} to edit the release."
  fi

}
