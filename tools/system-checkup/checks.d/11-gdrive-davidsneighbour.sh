#!/bin/bash
#
# Google Drive account "davidsneighbour" (google-drive-ocamlfuse) is mounted and its
# root folder answers a listing.

# Checks run through system-checkup, which exports SYSTEM_CHECKUP_DIR.
: "${SYSTEM_CHECKUP_DIR:?run this check with: system-checkup --check <name>}"
# shellcheck source=tools/system-checkup/lib.sh
source "${SYSTEM_CHECKUP_DIR}/lib.sh"

check_gdrive_label "davidsneighbour"
