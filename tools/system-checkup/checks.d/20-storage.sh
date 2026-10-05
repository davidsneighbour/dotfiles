#!/bin/bash
#
# External "Storage" drive is mounted at /mnt/storage (fstab, nofail) and its
# root folder answers a listing. The docker backup cron jobs write here.

# Checks run through system-checkup, which exports SYSTEM_CHECKUP_DIR.
: "${SYSTEM_CHECKUP_DIR:?run this check with: system-checkup --check <name>}"
# shellcheck source=tools/system-checkup/lib.sh
source "${SYSTEM_CHECKUP_DIR}/lib.sh"

if ! check_mount_responds "/mnt/storage" "ext4"; then
  printf 'Fix: check that the drive is connected, then run: sudo mount /mnt/storage\n'
  exit 1
fi
