# shellcheck shell=bash

# example usage
#
# set verbosity, then call the function
#
# ```
# verbose=true
# create_changelog
# ```

create_changelog() {
  # Use externally defined verbose variable, default to 'false' if not set
  local is_verbose="${verbose:-false}"

  local release_notes
  local cmd_status

  # Capture output and exit status of commit-and-tag-version
  release_notes=$(
    npx commit-and-tag-version --dry-run 2>/dev/null | \
      sed -r 's/\x1B\[[0-9;]*[mK]//g' | \
      awk 'BEGIN { flag=0 } /^---$/ { if (flag == 0) { flag=1 } else { flag=2 }; next } flag == 1'
  )
  cmd_status=$?

  # If the underlying command failed, propagate the failure
  if [ "${cmd_status}" -ne 0 ]; then
    echo "Error: commit-and-tag-version failed with exit code ${cmd_status}."
    return "${cmd_status}"
  fi

  # If we got release notes, handle them as before
  if [ -n "${release_notes}" ]; then
    RELEASE_NOTES="${release_notes}"
    echo "${RELEASE_NOTES}" > changes.md

    if [ "${is_verbose}" = "true" ]; then
      echo "Release notes generated and saved to changes.md:"
      echo '```'
      echo "${RELEASE_NOTES}"
      echo '```'
    fi

    # Open in VS Code locally; in CI this usually does nothing / is skipped
    if command -v code >/dev/null 2>&1; then
      code changes.md
    fi
    return 0
  fi

  # No notes, but command succeeded: treat as "changelog creation skipped"
  if [ "${is_verbose}" = "true" ]; then
    echo "Changelog creation skipped: commit-and-tag-version did not output changelog content (likely disabled via skip.changelog)."
  fi

  # Do not fail CI in this case
  return 0
}
