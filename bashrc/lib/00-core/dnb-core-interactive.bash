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
